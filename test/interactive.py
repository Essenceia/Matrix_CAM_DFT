
async def init(dut): 
	# rst 
	dut.rst_n.value = 0
	dut.ui_in.value = 0
	dut.uio_in.value = 0
	await ClockCycles(dut.clk, 10)
	dut.rst_n.value = 1 
	await ClockCycles(dut.clk, 10)
	# reset address data
	await mac_utils.rst_data_addr(dut)
	
async def write_weights(dut, log, W):
	log.info(f"writing weight matrix {W}") 
	await mac_utils.write_config(dut, W, weight=True)

# can't kick off multiple async threads in tt microphyton thus I must do this manually
# just don't read the code and everything will be fine
async def write_data(dut, log, D) -> R:
	log.info(f"writing data matrix {D}")
	
    config = bytearray(0)
    res = array("b")
	b = 0

    for x in X:
        assert x >= -128 and x <= 127
        config.append(stou(D))

    for i in range(0, 4):
        dut.ui_in.value = (config[i] << 1) & 0xFE
        uio_in = get_cmd(valid=True, mode=weight) | (config[i] >> 7 & 0x01)
        dut.uio_in.value = uio_in
        log.debug("write config %d:%s %s", i, config[i], uio_in)

		if (dut.uio_out.value & 0x80 ):
			 x = dut.uo_out.value.to_signed()
            res.append(x) 	

        await ClockCycles(dut.clk, 1)
    dut.uio_in.value = 0

    while (len(res) != N * N) and (b < 100):
		log.debug(f"reading the rest of the result, current len {len(res)}")
        if dut.result_v.value == 1:
            x = dut.uo_out.value.to_signed()
            res.append(x) 	while len(rst
		b = b+1 # bail condition to prevent deadlooping

	log.info(f"result read {res}")
	return res
