import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_simple(dut):
    """最簡單的測試，確保環境正常"""
    
    # 啟動時鐘
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # 復位
    dut.rst_n.value = 0
    await Timer(100, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut._log.info("✅ Simple test passed - Environment is working!")
