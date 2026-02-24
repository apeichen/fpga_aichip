#!/usr/bin/env python3
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_xr_integration(dut):
    """測試 XR 核心整合 (XSM + XENOS) - 確保 power_good"""
    dut._log.info("=" * 60)
    dut._log.info("Starting XR CORE INTEGRATION test...")
    dut._log.info("=" * 60)

    # 启动时钟
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())

    # 复位
    dut.rst_n.value = 0
    await Timer(100, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    dut._log.info("Reset released")

    # 设置正常范围内的 ADC 值
    dut.vin_adc.value = 10000
    dut.vout_adc.value = 5000
    dut.iout_adc.value = 3000
    dut.temp_adc.value = 500
    
    # 除錯：確認 ADC 設定值
    dut._log.info(f"[DEBUG] ADC values - vin:{dut.vin_adc.value}, vout:{dut.vout_adc.value}, iout:{dut.iout_adc.value}, temp:{dut.temp_adc.value}")

    # 启用捕获
    dut.capture_en.value = 1
    await RisingEdge(dut.clk)
    dut._log.info("Capture enabled")

    # 等待 XENOS 初始化
    await Timer(200, units='ns')

    # Test 1: XSM capture
    dut._log.info("\nTest 1: XSM capture")
    
    dut.trigger_in.value = 1
    await Timer(2, units='ns')
    dut.trigger_in.value = 0
    await Timer(8, units='ns')
    
    if dut.data_valid.value:
        data = int(dut.captured_data.value)
        channel = int(dut.captured_channel.value)
        dut._log.info(f"  ✅ Captured: channel={channel}, data=0x{data:04X} ({data})")
        # 除錯：XENOS 輸入值
        dut._log.info(f"  [DEBUG] XENOS inputs - vin:{dut.u_xenos.voltage.value}, iout:{dut.u_xenos.current.value}, temp:{dut.u_xenos.temperature.value}")

    # Test 2: XENOS state
    dut._log.info("\nTest 2: XENOS state")
    
    state_val = int(dut.system_state.value)
    fault = int(dut.fault_out.value)
    safe = int(dut.safe_out.value)
    viol_valid = int(dut.violation_valid.value)
    
    dut._log.info(f"  System state: {state_val}")
    dut._log.info(f"  Fault out: {fault}")
    dut._log.info(f"  Safe out: {safe}")
    dut._log.info(f"  Violation valid: {viol_valid}")
    
    assert state_val == 1, f"Expected IDLE(1), got {state_val}"
    assert viol_valid == 0, "Expected no violation"

    # Test 3: Power on request
    dut._log.info("\nTest 3: Power on request")
    
    dut.power_on_req.value = 1
    await Timer(50, units='ns')
    dut.power_on_req.value = 0
    await Timer(50, units='ns')
    
    state_val = int(dut.system_state.value)
    power_en = int(dut.power_enable.value)
    dut._log.info(f"  System state: {state_val}")
    dut._log.info(f"  Power enable: {power_en}")
    
    assert state_val == 2, f"Expected RUN(2), got {state_val}"
    assert power_en == 1, "Expected power enable"

    # Test 4: Fault injection via XSM
    dut._log.info("\nTest 4: Fault injection via XSM")
    
    # 除錯：設定故障值前的狀態
    dut._log.info(f"[DEBUG] Before fault - iout_adc:{dut.iout_adc.value}, XENOS current:{dut.u_xenos.current.value}")
    
    # 設置超限電流
    dut.iout_adc.value = 6000
    dut._log.info(f"[DEBUG] After setting - iout_adc:{dut.iout_adc.value}")
    
    # 發送多次觸發，確保值被更新
    for i in range(5):
        dut.trigger_in.value = 1
        await Timer(2, units='ns')
        dut.trigger_in.value = 0
        await Timer(8, units='ns')
        
        if dut.data_valid.value:
            channel = int(dut.captured_channel.value)
            data = int(dut.captured_data.value)
            dut._log.info(f"  Trigger {i}: captured ch={channel}, data={data}")
            dut._log.info(f"  [DEBUG] XENOS now - iout:{dut.u_xenos.current.value}")
    
    await Timer(100, units='ns')
    
    state_val = int(dut.system_state.value)
    fault = int(dut.fault_out.value)
    safe = int(dut.safe_out.value)
    viol_valid = int(dut.violation_valid.value)
    viol_code = int(dut.violation_code.value)
    
    dut._log.info(f"  System state: {state_val}")
    dut._log.info(f"  Fault out: {fault}")
    dut._log.info(f"  Safe out: {safe}")
    dut._log.info(f"  Violation: valid={viol_valid}, code=0x{viol_code:08X}")
    dut._log.info(f"  [DEBUG] Final XENOS current:{dut.u_xenos.current.value}")
    
    assert state_val == 4, f"Expected SAFE(4), got {state_val}"
    assert viol_valid == 1, "Expected violation"

    # Test 5: Recovery
    dut._log.info("\nTest 5: Recovery")
    
    # 恢復正常值
    dut.iout_adc.value = 3000
    dut._log.info(f"[DEBUG] Recovery - set iout_adc=3000")
    
    # 等待一個時鐘週期讓設定生效
    await Timer(1, unit='ns')
    
    # 立即讀取確認
    dut._log.info(f"[DEBUG] Verification - iout_adc now:{dut.iout_adc.value}")
    
    # 發送多次觸發，確保值被更新
    for i in range(5):
        dut.trigger_in.value = 1
        await Timer(2, unit='ns')
        dut.trigger_in.value = 0
        await Timer(8, unit='ns')
        
        if dut.data_valid.value:
            channel = int(dut.captured_channel.value)
            data = int(dut.captured_data.value)
            dut._log.info(f"  Recovery trigger {i}: captured ch={channel}, data={data}")
            dut._log.info(f"  [DEBUG] XENOS current now:{dut.u_xenos.current.value}")
    
    # 等待恢復計數器
    await Timer(300, unit='ns')
    
    # 重新發送 power_on_req
    dut.power_on_req.value = 1
    await Timer(50, unit='ns')
    dut.power_on_req.value = 0
    await Timer(100, unit='ns')
    
    state_val = int(dut.system_state.value)
    dut._log.info(f"  System state: {state_val}")
    dut._log.info(f"  [DEBUG] After recovery - XENOS current:{dut.u_xenos.current.value}")
    
    # 應該回到 RUN(2)
    assert state_val == 2, f"Expected RUN(2), got {state_val}"

    dut._log.info("\n" + "=" * 60)
    dut._log.info("✅ ALL TESTS PASSED!")
    dut._log.info("=" * 60)
