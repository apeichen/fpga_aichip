import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_xsm_basic(dut):
    """測試 XSM 基本功能"""
    
    dut._log.info("=" * 50)
    dut._log.info("Starting XSM test with simple version...")
    dut._log.info("=" * 50)
    
    # 啟動時鐘 (100MHz)
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # 復位
    dut.rst_n.value = 0
    await Timer(100, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    dut._log.info("Reset released")
    
    # 設置測試值
    test_value = 0x1234
    dut.vin_adc.value = test_value
    dut._log.info(f"Set vin_adc = 0x{test_value:04X}")
    
    # 啟用捕獲
    dut.capture_en.value = 1
    await RisingEdge(dut.clk)
    dut._log.info("Capture enabled")
    
    # 發送觸發信號
    dut._log.info("Sending trigger...")
    dut.trigger_in.value = 1
    await Timer(30, units='ns')
    dut.trigger_in.value = 0
    dut._log.info("Trigger sent")
    
    # 等待並檢查結果
    await Timer(50, units='ns')
    
    # 檢查結果
    sample_valid_val = int(dut.sample_valid.value)
    sample_data_val = int(dut.sample_data.value)
    mono_counter_val = int(dut.mono_counter.value)
    
    dut._log.info(f"sample_valid = {sample_valid_val}")
    dut._log.info(f"sample_data = 0x{sample_data_val:04X}")
    dut._log.info(f"mono_counter = {mono_counter_val}")
    
    if sample_valid_val:
        dut._log.info("✅ SUCCESS: Sample captured!")
        if sample_data_val == test_value:
            dut._log.info("✅ Data matches expected value!")
        else:
            dut._log.error(f"❌ Data mismatch: expected 0x{test_value:04X}, got 0x{sample_data_val:04X}")
    else:
        dut._log.error("❌ FAIL: No sample captured")
    
    assert sample_valid_val == 1, "No sample captured"
    assert sample_data_val == test_value, "Data mismatch"
    
    dut._log.info("=" * 50)
    dut._log.info("✅ Test passed!")
    dut._log.info("=" * 50)
