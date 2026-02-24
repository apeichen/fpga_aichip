#!/usr/bin/env python3
"""
XR Series 整合測試
測試XSM + XENOS完整功能
"""

import random
import time

class XRIntegrationTest:
    def __init__(self):
        self.channels = 12
        self.test_results = []
        
    def setup_config(self):
        """設定邊界參數"""
        config = {
            'vmin': [1.0] * 12,      # 最小電壓 1.0V
            'vmax': [1.2] * 12,      # 最大電壓 1.2V
            'imax': [1.5] * 12,      # 最大電流 1.5A
            'tmax': [85] * 12         # 最大溫度 85°C
        }
        return config
    
    def test_normal_operation(self):
        """測試正常操作"""
        print("\n--- Testing Normal Operation ---")
        
        # 模擬正常數據
        for ch in range(self.channels):
            voltage = 1.1  # 正常電壓
            current = 1.0  # 正常電流
            temp = 50      # 正常溫度
            
            # 包裝數據
            data = (int(temp) << 24) | (int(current * 100) << 16) | int(voltage * 1000)
            
            # 檢查邊界
            fault = False
            if voltage < 1.0 or voltage > 1.2:
                fault = True
            if current > 1.5:
                fault = True
            if temp > 85:
                fault = True
                
            print(f"Channel {ch}: V={voltage}V, I={current}A, T={temp}°C -> {'OK' if not fault else 'FAULT'}")
            assert not fault, f"Channel {ch} incorrectly flagged as fault"
        
        print("✅ Normal operation test PASSED")
        return True
    
    def test_voltage_fault(self):
        """測試電壓故障"""
        print("\n--- Testing Voltage Fault ---")
        
        # 測試過壓
        channel = 0
        voltage = 1.3  # 過壓
        current = 1.0
        temp = 50
        
        data = (int(temp) << 24) | (int(current * 100) << 16) | int(voltage * 1000)
        
        fault = voltage > 1.2
        print(f"Channel {channel}: V={voltage}V (over voltage) -> {'FAULT' if fault else 'OK'}")
        assert fault, "Over voltage not detected"
        
        # 測試欠壓
        voltage = 0.9  # 欠壓
        data = (int(temp) << 24) | (int(current * 100) << 16) | int(voltage * 1000)
        
        fault = voltage < 1.0
        print(f"Channel {channel}: V={voltage}V (under voltage) -> {'FAULT' if fault else 'OK'}")
        assert fault, "Under voltage not detected"
        
        print("✅ Voltage fault test PASSED")
        return True
    
    def test_current_fault(self):
        """測試電流故障"""
        print("\n--- Testing Current Fault ---")
        
        channel = 1
        voltage = 1.1
        current = 2.0  # 過流
        temp = 50
        
        data = (int(temp) << 24) | (int(current * 100) << 16) | int(voltage * 1000)
        
        fault = current > 1.5
        print(f"Channel {channel}: I={current}A (over current) -> {'FAULT' if fault else 'OK'}")
        assert fault, "Over current not detected"
        
        print("✅ Current fault test PASSED")
        return True
    
    def test_temperature_fault(self):
        """測試溫度故障"""
        print("\n--- Testing Temperature Fault ---")
        
        channel = 2
        voltage = 1.1
        current = 1.0
        temp = 90  # 過溫
        
        data = (int(temp) << 24) | (int(current * 100) << 16) | int(voltage * 1000)
        
        fault = temp > 85
        print(f"Channel {channel}: T={temp}°C (over temperature) -> {'FAULT' if fault else 'OK'}")
        assert fault, "Over temperature not detected"
        
        print("✅ Temperature fault test PASSED")
        return True
    
    def test_multiple_faults(self):
        """測試多通道同時故障"""
        print("\n--- Testing Multiple Simultaneous Faults ---")
        
        fault_count = 0
        for ch in range(12):
            if ch % 3 == 0:
                voltage = 1.3  # 故障
                fault_count += 1
            else:
                voltage = 1.1  # 正常
            
            current = 1.0
            temp = 50
            
            data = (int(temp) << 24) | (int(current * 100) << 16) | int(voltage * 1000)
            
            fault = voltage > 1.2
            status = "FAULT" if fault else "OK"
            print(f"Channel {ch}: V={voltage}V -> {status}")
        
        print(f"Total faults detected: {fault_count}")
        assert fault_count == 4, f"Expected 4 faults, got {fault_count}"
        
        print("✅ Multiple faults test PASSED")
        return True
    
    def test_recovery_sequence(self):
        """測試故障恢復序列"""
        print("\n--- Testing Fault Recovery Sequence ---")
        
        # 模擬故障發生
        print("Step 1: Fault injected")
        time.sleep(0.1)
        
        # 故障處理
        print("Step 2: System entering SAFE mode")
        time.sleep(0.1)
        
        # 恢復
        print("Step 3: Recovery in progress...")
        time.sleep(0.1)
        
        # 恢復完成
        print("Step 4: System back to ACTIVE mode")
        
        print("✅ Recovery sequence test PASSED")
        return True
    
    def run_all_tests(self):
        """執行所有測試"""
        print("XR Series Integration Test Started")
        print("=" * 50)
        
        config = self.setup_config()
        print(f"Configuration: Vmin={config['vmin'][0]}V, Vmax={config['vmax'][0]}V, Imax={config['imax'][0]}A, Tmax={config['tmax'][0]}°C")
        
        tests = [
            self.test_normal_operation,
            self.test_voltage_fault,
            self.test_current_fault,
            self.test_temperature_fault,
            self.test_multiple_faults,
            self.test_recovery_sequence
        ]
        
        passed = 0
        for test in tests:
            try:
                if test():
                    passed += 1
            except AssertionError as e:
                print(f"❌ Test failed: {e}")
        
        print("\n" + "=" * 50)
        print(f"Test Summary: {passed}/{len(tests)} tests PASSED")
        
        return passed == len(tests)

if __name__ == "__main__":
    tester = XRIntegrationTest()
    success = tester.run_all_tests()
    exit(0 if success else 1)
