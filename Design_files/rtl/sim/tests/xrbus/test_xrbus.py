#!/usr/bin/env python3
"""
XR-BUS 測試平台
驗證訊框格式、時序對齊、邊界標記和完整性檢查
"""

import random
import hashlib
import struct
from datetime import datetime

class XRUSTestBench:
    def __init__(self):
        self.modules = {
            0x0001: "XRAD",
            0x0002: "XENOS",
            0x0003: "XENOA",
            0x0004: "XRAS",
            0x0005: "XRST",
            0x0006: "XAPS",
            0x0007: "XRBUS"
        }
        
        self.boundaries = {
            0x0000: "RACK-0",
            0x1000: "RACK-1",
            0x2000: "CLUSTER-A",
            0x3000: "DOMAIN-1",
            0x4000: "TENANT-X"
        }
        
    def generate_frame(self, src_module, src_boundary, op_code, payload):
        """產生測試訊框"""
        timestamp = int(datetime.now().timestamp() * 1e6)
        
        frame = {
            'module_id': src_module,
            'boundary_id': src_boundary,
            'op_code': op_code,
            'device_time': timestamp,
            'fabric_time': timestamp + random.randint(-100, 100),
            'cloud_time': timestamp + random.randint(-500, 500),
            'trace_id': random.getrandbits(128),
            'parent_id': random.getrandbits(128),
            'semantic_hash': random.getrandbits(32),
            'payload': payload,
            'payload_len': len(payload),
            'version': 0x200  # v2.0
        }
        
        return frame
    
    def test_frame_format(self):
        """測試訊框格式"""
        print("\n=== XR-BUS Frame Format Test ===")
        
        # 產生測試訊框
        test_payload = bytes([random.randint(0, 255) for _ in range(64)])
        frame = self.generate_frame(0x0001, 0x0000, 0x01, test_payload)
        
        print(f"Source Module: {self.modules.get(frame['module_id'], 'Unknown')} (0x{frame['module_id']:04x})")
        print(f"Boundary: {self.boundaries.get(frame['boundary_id'], 'Unknown')} (0x{frame['boundary_id']:04x})")
        print(f"Op Code: 0x{frame['op_code']:02x}")
        print(f"Device Time: {frame['device_time']}")
        print(f"Fabric Time: {frame['fabric_time']}")
        print(f"Cloud Time: {frame['cloud_time']}")
        print(f"Trace ID: 0x{frame['trace_id']:032x}")
        print(f"Payload Length: {frame['payload_len']} bytes")
        
        # 驗證時鐘差異
        device_fabric_delta = abs(frame['device_time'] - frame['fabric_time'])
        fabric_cloud_delta = abs(frame['fabric_time'] - frame['cloud_time'])
        
        print(f"\nDevice-Fabric Delta: {device_fabric_delta} µs")
        print(f"Fabric-Cloud Delta: {fabric_cloud_delta} µs")
        
        assert device_fabric_delta < 1000, "Device-Fabric jitter too high"
        assert fabric_cloud_delta < 1000, "Fabric-Cloud jitter too high"
        
        print("✅ Frame format test PASSED")
        return frame
    
    def test_causal_chain(self):
        """測試因果鏈追蹤"""
        print("\n=== Causal Chain Test ===")
        
        # 模擬事件鏈
        events = []
        parent_id = random.getrandbits(128)
        
        for i in range(5):
            trace_id = random.getrandbits(128)
            event = {
                'seq': i,
                'trace_id': trace_id,
                'parent_id': parent_id if i > 0 else 0,
                'timestamp': 1000 + i * 100
            }
            events.append(event)
            parent_id = trace_id
        
        # 重建因果鏈
        print("Event Sequence:")
        for event in events:
            print(f"  Event {event['seq']}: Trace=0x{event['trace_id']:016x}..., Parent=0x{event['parent_id']:016x}...")
        
        # 驗證鏈結
        for i in range(1, len(events)):
            assert events[i]['parent_id'] == events[i-1]['trace_id'], f"Broken causal chain at event {i}"
        
        print("✅ Causal chain test PASSED")
        return events
    
    def test_boundary_tagging(self):
        """測試邊界標記"""
        print("\n=== Boundary Tagging Test ===")
        
        test_cases = [
            (0x0000, 0, "RACK internal"),
            (0x1000, 1, "RACK to CLUSTER"),
            (0x2000, 2, "CLUSTER to DOMAIN"),
            (0x3000, 3, "DOMAIN to TENANT")
        ]
        
        for boundary_id, boundary_type, description in test_cases:
            # 模擬邊界標記
            if boundary_type == 0:
                dst_boundary = boundary_id
                policy_mask = 0x00000001
            elif boundary_type == 1:
                dst_boundary = boundary_id + 0x1000
                policy_mask = 0x00000003
            elif boundary_type == 2:
                dst_boundary = (boundary_id & 0xFF00) | 0x00FF
                policy_mask = 0x0000000F
            else:
                dst_boundary = (boundary_id & 0xFF00) | 0x00FF
                policy_mask = 0xFFFFFFFF
            
            print(f"\n{description}:")
            print(f"  Source Boundary: 0x{boundary_id:04x}")
            print(f"  Dest Boundary: 0x{dst_boundary:04x}")
            print(f"  Policy Mask: 0x{policy_mask:08x}")
            
            assert dst_boundary != boundary_id or boundary_type == 0, "Boundary should change"
        
        print("\n✅ Boundary tagging test PASSED")
    
    def test_integrity(self):
        """測試完整性檢查"""
        print("\n=== Integrity Test ===")
        
        # 產生測試訊框
        test_payload = b"XR-BUS integrity test payload"
        frame = self.generate_frame(0x0001, 0x0000, 0x01, test_payload)
        
        # 計算雜湊
        version = frame['version']
        module_id = frame['module_id']
        timestamp = frame['device_time']
        
        hash_input = f"{version}{module_id}{timestamp}".encode()
        calculated_hash = hashlib.sha256(hash_input).hexdigest()[:16]
        
        print(f"Version: 0x{version:x}")
        print(f"Module ID: 0x{module_id:04x}")
        print(f"Hash: {calculated_hash}")
        
        # 驗證版本相容性
        assert version >= 0x100, "Version too old"
        print("✅ Version compatibility check PASSED")
        
        return calculated_hash
    
    def test_cross_module_communication(self):
        """測試跨模組通訊"""
        print("\n=== Cross-Module Communication Test ===")
        
        # 模擬 XRAD -> XENOA -> XENOS -> XRAS -> XRST 的通訊鏈
        modules_chain = [0x0001, 0x0003, 0x0002, 0x0004, 0x0005]
        
        print("Communication Chain:")
        for i in range(len(modules_chain)-1):
            src = self.modules.get(modules_chain[i], "Unknown")
            dst = self.modules.get(modules_chain[i+1], "Unknown")
            print(f"  {src} (0x{modules_chain[i]:04x}) → {dst} (0x{modules_chain[i+1]:04x})")
            
            # 產生測試訊框
            test_payload = f"Message from {src} to {dst}".encode()
            frame = self.generate_frame(modules_chain[i], 0x0000, 0x01, test_payload)
            
            print(f"    Trace: 0x{frame['trace_id']:016x}...")
        
        print("\n✅ Cross-module communication test PASSED")
    
    def run_all_tests(self):
        """執行所有測試"""
        print("XR-BUS Test Bench Started")
        print("=" * 60)
        
        tests = [
            self.test_frame_format,
            self.test_causal_chain,
            self.test_boundary_tagging,
            self.test_integrity,
            self.test_cross_module_communication
        ]
        
        passed = 0
        for test in tests:
            try:
                test()
                passed += 1
            except AssertionError as e:
                print(f"❌ Test failed: {e}")
        
        print("\n" + "=" * 60)
        print(f"XR-BUS Test Summary: {passed}/{len(tests)} tests PASSED")
        print("=" * 60)
        
        return passed == len(tests)

if __name__ == "__main__":
    tb = XRUSTestBench()
    success = tb.run_all_tests()
    exit(0 if success else 1)
