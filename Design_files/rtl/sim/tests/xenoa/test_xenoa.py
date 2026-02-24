#!/usr/bin/env python3
"""
XENOA 測試平台
測試語義標準化、時序對齊、邊界映射和推理基質
"""

import random
import hashlib
import struct
from datetime import datetime

class XENOATestBench:
    def __init__(self):
        self.signal_types = {
            0: "SI/PI Drift",
            1: "Thermal Decay",
            2: "SSD Tail Latency",
            3: "Firmware Divergence",
            4: "Jitter Accumulation",
            5: "Micro-event"
        }
        
        self.boundaries = {
            0: "RACK",
            1: "CLUSTER", 
            2: "DOMAIN",
            3: "TENANT"
        }
        
        self.units = {
            0: "none",
            1: "mV",
            2: "mA",
            3: "mW",
            4: "°C",
            5: "µs",
            6: "ppm",
            7: "count"
        }
        
    def generate_signal(self, signal_type, value_range):
        """產生測試信號"""
        min_val, max_val, unit = value_range
        value = random.uniform(min_val, max_val * 1.5)  # 可能超出範圍
        return {
            'type': signal_type,
            'value': value,
            'unit': unit,
            'timestamp': datetime.now().timestamp() * 1e6
        }
    
    def test_semantic_standardization(self):
        """測試語義標準化"""
        print("\n=== XENOA Semantic Standardization Test ===")
        
        test_cases = [
            (0, (1100, 1300, "mV"), "SI/PI Drift"),
            (1, (25, 85, "°C"), "Thermal Decay"),
            (2, (100, 1000, "µs"), "SSD Tail Latency"),
            (3, (0, 1, "count"), "Firmware Divergence"),
            (4, (0, 1000, "µs"), "Jitter Accumulation"),
            (5, (0, 1, "none"), "Micro-event")
        ]
        
        for signal_type, (min_val, max_val, unit), name in test_cases:
            signal = self.generate_signal(signal_type, (min_val, max_val, unit))
            
            # 計算標準化值 (0-1000)
            if signal['value'] < min_val:
                normalized = 0
                deviation = min_val - signal['value']
                severity = 8  # 欠標
            elif signal['value'] > max_val:
                normalized = 1000
                deviation = signal['value'] - max_val
                severity = 12  # 過標
            else:
                normalized = int((signal['value'] - min_val) * 1000 / (max_val - min_val))
                deviation = 0
                severity = 0  # 正常
            
            print(f"\n{name}:")
            print(f"  Raw Value: {signal['value']:.2f} {unit}")
            print(f"  Nominal Range: {min_val} - {max_val} {unit}")
            print(f"  Normalized: {normalized}/1000")
            print(f"  Deviation: {deviation:.2f} {unit}")
            print(f"  Severity: {severity}")
            
            # 驗證
            if signal['value'] < min_val:
                assert deviation > 0, "Should detect under-range"
            elif signal['value'] > max_val:
                assert deviation > 0, "Should detect over-range"
            else:
                assert 0 <= normalized <= 1000, "Normalized value out of range"
        
        print("\n✅ Semantic standardization test PASSED")
    
    def test_temporal_alignment(self):
        """測試時序對齊"""
        print("\n=== XENOA Temporal Alignment Test ===")
        
        # 模擬多時鐘域
        base_time = 1000000  # 1秒
        device_time = base_time
        fabric_time = base_time + random.randint(-100, 100)
        cloud_time = base_time + random.randint(-500, 500)
        
        window_size = 100000000  # 100ms
        current_window = cloud_time // window_size
        
        print(f"Device Time: {device_time} ns")
        print(f"Fabric Time: {fabric_time} ns (Δ={fabric_time-base_time} ns)")
        print(f"Cloud Time: {cloud_time} ns (Δ={cloud_time-base_time} ns)")
        print(f"Time Window: {current_window}")
        
        # 驗證時間視窗
        delta_df = abs(device_time - fabric_time)
        delta_fc = abs(fabric_time - cloud_time)
        
        assert delta_df < 1000, f"Device-Fabric delta too high: {delta_df} ns"
        assert delta_fc < 1000, f"Fabric-Cloud delta too high: {delta_fc} ns"
        
        print(f"\nDevice-Fabric Delta: {delta_df} ns ✓")
        print(f"Fabric-Cloud Delta: {delta_fc} ns ✓")
        print("✅ Temporal alignment test PASSED")
        
        return current_window
    
    def test_boundary_mapping(self):
        """測試邊界映射"""
        print("\n=== XENOA Boundary Mapping Test ===")
        
        normalized_value = 500  # 中間值
        severity = 4
        
        for boundary_type, name in self.boundaries.items():
            # 邊界調整因子
            if boundary_type == 0:
                contract_value = normalized_value
            elif boundary_type == 1:
                contract_value = normalized_value * 2
            elif boundary_type == 2:
                contract_value = normalized_value * 5
            else:
                contract_value = normalized_value * 10
            
            print(f"\n{name} Boundary:")
            print(f"  Normalized Value: {normalized_value}")
            print(f"  Contract Value: {contract_value}")
            print(f"  Severity: {severity}")
            
            # 驗證
            if boundary_type > 0:
                assert contract_value > normalized_value, "Boundary scaling incorrect"
        
        print("\n✅ Boundary mapping test PASSED")
    
    def test_pattern_recognition(self):
        """測試模式識別"""
        print("\n=== XENOA Pattern Recognition Test ===")
        
        # 產生趨勢數據
        trends = [
            ([100, 102, 105, 110, 120], "Rising"),
            ([100, 98, 95, 90, 80], "Falling"),
            ([100, 101, 99, 102, 100], "Stable"),
            ([100, 150, 200, 250, 300], "Sharp Rise"),
            ([100, 50, 25, 10, 0], "Sharp Fall")
        ]
        
        for values, trend_name in trends:
            # 計算趨勢
            deltas = [values[i+1] - values[i] for i in range(len(values)-1)]
            avg_delta = sum(deltas) / len(deltas)
            
            if avg_delta > 20:
                trend_code = 3  # 急遽上升
                trend_desc = "Sharp Rise"
            elif avg_delta > 5:
                trend_code = 2  # 緩慢上升
                trend_desc = "Gradual Rise"
            elif avg_delta < -20:
                trend_code = 13  # 急遽下降
                trend_desc = "Sharp Fall"
            elif avg_delta < -5:
                trend_code = 12  # 緩慢下降
                trend_desc = "Gradual Fall"
            else:
                trend_code = 0  # 平穩
                trend_desc = "Stable"
            
            print(f"\n{trend_name} Pattern:")
            print(f"  Values: {values}")
            print(f"  Avg Delta: {avg_delta:.1f}")
            print(f"  Detected: {trend_desc} (code {trend_code})")
            
            # 驗證
            if trend_name == "Sharp Rise":
                assert trend_code == 3, "Should detect sharp rise"
            elif trend_name == "Sharp Fall":
                assert trend_code == 13, "Should detect sharp fall"
        
        print("\n✅ Pattern recognition test PASSED")
    
    def test_cross_module_integration(self):
        """測試跨模組整合 (XR-BUS → XENOA → XRAS)"""
        print("\n=== Cross-Module Integration Test ===")
        
        # 模擬 XR-BUS 訊框
        test_signal = {
            'module': 0x0003,  # XENOA
            'boundary': 0x3000,  # TENANT
            'type': 1,  # Thermal Decay
            'value': 95.0,  # 過溫
            'min': 25,
            'max': 85,
            'unit': '°C'
        }
        
        print(f"XR-BUS Input:")
        print(f"  Module: 0x{test_signal['module']:04x}")
        print(f"  Boundary: 0x{test_signal['boundary']:04x}")
        print(f"  Signal: {test_signal['type']}")
        print(f"  Value: {test_signal['value']} {test_signal['unit']}")
        print(f"  Range: {test_signal['min']}-{test_signal['max']} {test_signal['unit']}")
        
        # XENOA 處理
        if test_signal['value'] > test_signal['max']:
            deviation = test_signal['value'] - test_signal['max']
            severity = 12
            normalized = 1000
        else:
            deviation = 0
            severity = 0
            normalized = int((test_signal['value'] - test_signal['min']) * 1000 / 
                           (test_signal['max'] - test_signal['min']))
        
        print(f"\nXENOA Processing:")
        print(f"  Normalized: {normalized}/1000")
        print(f"  Deviation: {deviation:.1f} {test_signal['unit']}")
        print(f"  Severity: {severity}")
        
        # 邊界調整
        contract_value = normalized * 10  # TENANT 邊界
        print(f"\nBoundary Mapping (TENANT):")
        print(f"  Contract Value: {contract_value}")
        
        # 產生語義張量
        semantic_tensor = f"{test_signal['type']:02x}{severity:01x}{contract_value:04x}"
        pattern_hash = hashlib.md5(semantic_tensor.encode()).hexdigest()[:8]
        
        print(f"\nSemantic Tensor: {semantic_tensor}")
        print(f"Pattern Hash: {pattern_hash}")
        
        # 驗證
        assert severity == 12, "Should detect over-temperature"
        assert contract_value == 10000, "Boundary scaling incorrect"
        
        print("\n✅ Cross-module integration test PASSED")
        return pattern_hash
    
    def run_all_tests(self):
        """執行所有測試"""
        print("XENOA Test Bench Started")
        print("=" * 60)
        
        tests = [
            self.test_semantic_standardization,
            self.test_temporal_alignment,
            self.test_boundary_mapping,
            self.test_pattern_recognition,
            self.test_cross_module_integration
        ]
        
        passed = 0
        for test in tests:
            try:
                test()
                passed += 1
            except AssertionError as e:
                print(f"❌ Test failed: {e}")
        
        print("\n" + "=" * 60)
        print(f"XENOA Test Summary: {passed}/{len(tests)} tests PASSED")
        print("=" * 60)
        
        return passed == len(tests)

if __name__ == "__main__":
    tb = XENOATestBench()
    success = tb.run_all_tests()
    exit(0 if success else 1)
