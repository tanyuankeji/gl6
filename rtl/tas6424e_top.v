// ============================================================================
// TAS6424E-Q1 顶层集成模块 (v6.0)
// 功能: 集成所有子模块, 56引脚接口
// 设计原则:
//   - 12子模块 (4 core FSM + 8 外围)
//   - 清晰的分层结构: 顶层→FSM→诊断/音频/保护
//   - 所有跨模块信号通过wire连接
// ============================================================================

module tas6424e_top (
    // 系统信号
    input  wire         clk,
    input  wire         rst_n,
    // I2C接口
    input  wire         scl_i,
    inout  wire         sda_io,
    input  wire [1:0]   i2c_addr_i,
    // 音频接口
    input  wire         mclk_i,
    input  wire         sclk_i,
    input  wire         fsync_i,
    input  wire         sd_in1_i,
    input  wire         sd_in2_i,
    // 硬件控制引脚
    input  wire         standby_n_i,
    input  wire         mute_n_i,
    output wire         fault_n_o,
    output wire         warn_n_o,
    // PWM输出 (4通道BTL)
    output wire         out_1p_o, out_1m_o,
    output wire         out_2p_o, out_2m_o,
    output wire         out_3p_o, out_3m_o,
    output wire         out_4p_o, out_4m_o,
    // 模拟前端输入
    input  wire         otw_raw_i, otsd_raw_i,
    input  wire [3:0]   otw_ch_raw_i, otsd_ch_raw_i,
    input  wire         vbat_uv_raw_i, vbat_ov_raw_i,
    input  wire         pvdd_uv_raw_i, pvdd_ov_raw_i,
    input  wire [3:0]   oc_ch_i, dc_ch_i,
    input  wire         por_vdd_i,
    // 模拟前端诊断输入
    input  wire [3:0]   s2g_ch_i, s2p_ch_i, ol_ch_i, sl_ch_i, lo_ch_i
);

    // ========================================================================
    // 内部信号声明
    // ========================================================================

    // ---- chip_top_controller ----
    wire [1:0] chip_state;
    wire       chip_active;
    wire       oscillator_en;
    wire       any_ch_play, any_ch_mute, all_ch_hiz, any_ch_diag, any_ch_ac;

    // ---- pin_control ----
    wire standby_n_db, mute_n_db;

    // ---- i2c_slave ----
    wire       reg_wr_en, reg_rd_en;
    wire [7:0] reg_wr_addr, reg_wr_data, reg_rd_addr, reg_rd_data;

    // ---- register_file ----
    wire       soft_reset, pbtl_ch12, pbtl_ch34;
    wire       hpf_bypass, oc_level, ldg_bypass, ldg_lo_enable;
    wire       clear_fault_pulse, otsd_auto_recovery, phase_sel_msb;
    wire       tdm_slot_sel, tdm_slot_size;
    wire [1:0] otw_threshold, volume_rate, gain_level, input_sr, dc_ramp_settle, output_phase_lsb;
    wire [2:0] pwm_freq, sap_mode;
    wire [7:0] ch_state_ctrl, pin_ctrl;
    wire [3:0] ac_diag_en;

    // ---- hardware write ----
    wire       hw_wr_en;
    wire [7:0] hw_wr_addr, hw_wr_data;

    // ---- channel_fsm ×4 ----
    // 每通道: ch_state[2:0], ch_en, ch_mute, ch_diag_active, ch_ac_active, ch_fault_latched
    wire [2:0] ch0_state, ch1_state, ch2_state, ch3_state;
    wire [3:0] ch_en_vec, ch_mute_vec, ch_diag_vec, ch_ac_vec, ch_fault_vec;

    // ---- protection ----
    wire       otw_int, otsd_int;
    wire [3:0] otw_ch_int, otsd_ch_int;
    wire       vbat_uv_int, vbat_ov_int, pvdd_uv_int, pvdd_ov_int, otsd_recovered;

    // ---- clock_monitor ----
    wire clock_lost, mclk_lost, sclk_lost, fsync_lost;

    // ---- fault_monitor ----
    wire global_fault_irq;
    wire [3:0] ch_fault;
    wire fault_trigger, warn_trigger;
    wire [7:0] fm_hw_addr, fm_hw_data;
    wire       fm_hw_en;

    // ---- diagnostic FSMs ----
    wire [3:0] ch_diag_done, ch_ac_done;
    wire       dc_fsm_busy, ac_fsm_busy;
    wire [3:0] dc_diag_state;
    wire [2:0] ac_diag_state;
    wire [7:0] dc_hw_addr, dc_hw_data, ac_hw_addr, ac_hw_data;
    wire       dc_hw_en, ac_hw_en;

    // ---- audio_interface ----
    wire [23:0] audio_ch1, audio_ch2, audio_ch3, audio_ch4;
    wire        audio_valid;

    // ========================================================================
    // POR检测 (简化: por_vdd_i直接使用)
    // ========================================================================
    wire por_done;
    assign por_done = !por_vdd_i;  // POR=1表示异常, 0表示正常/完成

    // ========================================================================
    // 顶层控制器
    // ========================================================================
    chip_top_controller u_top (
        .clk(clk), .rst_n(rst_n),
        .por_done(por_done),
        .standby_n_db(standby_n_db),
        .chip_state(chip_state),
        .chip_active(chip_active),
        .oscillator_en(oscillator_en),
        .ch0_state(ch0_state), .ch1_state(ch1_state),
        .ch2_state(ch2_state), .ch3_state(ch3_state),
        .any_ch_play(any_ch_play), .any_ch_mute(any_ch_mute),
        .all_ch_hiz(all_ch_hiz), .any_ch_diag(any_ch_diag), .any_ch_ac(any_ch_ac)
    );

    // ========================================================================
    // 引脚控制
    // ========================================================================
    pin_control u_pin (
        .clk(clk), .rst_n(rst_n),
        .standby_n_i(standby_n_i), .mute_n_i(mute_n_i),
        .fault_trigger(fault_trigger), .warn_trigger(warn_trigger),
        .pin_ctrl(pin_ctrl),
        .fault_n_o(fault_n_o), .warn_n_o(warn_n_o),
        .standby_n_db(standby_n_db), .mute_n_db(mute_n_db)
    );

    // ========================================================================
    // I2C从机
    // ========================================================================
    i2c_slave u_i2c (
        .clk(clk), .rst_n(rst_n),
        .scl_i(scl_i), .sda_io(sda_io), .i2c_addr_i(i2c_addr_i),
        .reg_wr_en(reg_wr_en), .reg_wr_addr(reg_wr_addr), .reg_wr_data(reg_wr_data),
        .reg_rd_en(reg_rd_en), .reg_rd_addr(reg_rd_addr), .reg_rd_data(reg_rd_data)
    );

    // ========================================================================
    // 寄存器文件
    // ========================================================================
    register_file u_reg (
        .clk(clk), .rst_n(rst_n),
        .reg_wr_en(reg_wr_en), .reg_wr_addr(reg_wr_addr), .reg_wr_data(reg_wr_data),
        .reg_rd_en(reg_rd_en), .reg_rd_addr(reg_rd_addr), .reg_rd_data(reg_rd_data),
        .hw_wr_addr(hw_wr_addr), .hw_wr_data(hw_wr_data), .hw_wr_en(hw_wr_en),
        .soft_reset(soft_reset), .pbtl_ch12(pbtl_ch12), .pbtl_ch34(pbtl_ch34),
        .hpf_bypass(hpf_bypass), .otw_threshold(otw_threshold),
        .oc_level(oc_level), .volume_rate(volume_rate), .gain_level(gain_level),
        .pwm_freq(pwm_freq), .output_phase_lsb(output_phase_lsb),
        .input_sr(input_sr), .tdm_slot_sel(tdm_slot_sel),
        .tdm_slot_size(tdm_slot_size), .sap_mode(sap_mode),
        .ch_state_ctrl(ch_state_ctrl),
        .ldg_bypass(ldg_bypass), .ldg_lo_enable(ldg_lo_enable),
        .dc_ramp_settle(dc_ramp_settle),
        .pin_ctrl(pin_ctrl), .ac_diag_en(ac_diag_en),
        .clear_fault_pulse(clear_fault_pulse), .otsd_auto_recovery(otsd_auto_recovery),
        .phase_sel_msb(phase_sel_msb)
    );

    // ========================================================================
    // 硬件写仲裁 (fault_monitor + dc_diag + ac_diag) → register_file
    // ========================================================================
    wire [1:0] hw_sel;
    assign hw_sel = dc_hw_en ? 2'd1 : ac_hw_en ? 2'd2 : fm_hw_en ? 2'd3 : 2'd0;

    assign hw_wr_en   = (hw_sel != 2'd0);
    assign hw_wr_addr = (hw_sel == 2'd1) ? dc_hw_addr
                      : (hw_sel == 2'd2) ? ac_hw_addr : fm_hw_addr;
    assign hw_wr_data = (hw_sel == 2'd1) ? dc_hw_data
                      : (hw_sel == 2'd2) ? ac_hw_data : fm_hw_data;

    // ========================================================================
    // 通道FSM ×4
    // ========================================================================
    channel_fsm #(.CHANNEL_ID(0)) u_ch0 (
        .clk(clk), .rst_n(rst_n),
        .chip_active(chip_active), .global_fault(global_fault_irq),
        .clear_fault(clear_fault_pulse),
        .ch_state_req(ch_state_ctrl[1:0]),
        .ldg_bypass(ldg_bypass), .ac_diag_en(ac_diag_en[0]),
        .hw_mute_n(mute_n_db),
        .ch_fault(ch_fault[0]),
        .ch_diag_done(ch_diag_done[0]), .ch_ac_done(ch_ac_done[0]),
        .dc_ldg_abort(1'b0),  // TODO: connect from 0x09[7]
        .ch_state(ch0_state),
        .ch_en(ch_en_vec[0]), .ch_mute_mode(ch_mute_vec[0]),
        .ch_diag_active(ch_diag_vec[0]), .ch_ac_active(ch_ac_vec[0]),
        .ch_fault_latched(ch_fault_vec[0])
    );

    channel_fsm #(.CHANNEL_ID(1)) u_ch1 (
        .clk(clk), .rst_n(rst_n),
        .chip_active(chip_active), .global_fault(global_fault_irq),
        .clear_fault(clear_fault_pulse),
        .ch_state_req(ch_state_ctrl[3:2]),
        .ldg_bypass(ldg_bypass), .ac_diag_en(ac_diag_en[1]),
        .hw_mute_n(mute_n_db),
        .ch_fault(ch_fault[1]),
        .ch_diag_done(ch_diag_done[1]), .ch_ac_done(ch_ac_done[1]),
        .dc_ldg_abort(1'b0),
        .ch_state(ch1_state),
        .ch_en(ch_en_vec[1]), .ch_mute_mode(ch_mute_vec[1]),
        .ch_diag_active(ch_diag_vec[1]), .ch_ac_active(ch_ac_vec[1]),
        .ch_fault_latched(ch_fault_vec[1])
    );

    channel_fsm #(.CHANNEL_ID(2)) u_ch2 (
        .clk(clk), .rst_n(rst_n),
        .chip_active(chip_active), .global_fault(global_fault_irq),
        .clear_fault(clear_fault_pulse),
        .ch_state_req(ch_state_ctrl[5:4]),
        .ldg_bypass(ldg_bypass), .ac_diag_en(ac_diag_en[2]),
        .hw_mute_n(mute_n_db),
        .ch_fault(ch_fault[2]),
        .ch_diag_done(ch_diag_done[2]), .ch_ac_done(ch_ac_done[2]),
        .dc_ldg_abort(1'b0),
        .ch_state(ch2_state),
        .ch_en(ch_en_vec[2]), .ch_mute_mode(ch_mute_vec[2]),
        .ch_diag_active(ch_diag_vec[2]), .ch_ac_active(ch_ac_vec[2]),
        .ch_fault_latched(ch_fault_vec[2])
    );

    channel_fsm #(.CHANNEL_ID(3)) u_ch3 (
        .clk(clk), .rst_n(rst_n),
        .chip_active(chip_active), .global_fault(global_fault_irq),
        .clear_fault(clear_fault_pulse),
        .ch_state_req(ch_state_ctrl[7:6]),
        .ldg_bypass(ldg_bypass), .ac_diag_en(ac_diag_en[3]),
        .hw_mute_n(mute_n_db),
        .ch_fault(ch_fault[3]),
        .ch_diag_done(ch_diag_done[3]), .ch_ac_done(ch_ac_done[3]),
        .dc_ldg_abort(1'b0),
        .ch_state(ch3_state),
        .ch_en(ch_en_vec[3]), .ch_mute_mode(ch_mute_vec[3]),
        .ch_diag_active(ch_diag_vec[3]), .ch_ac_active(ch_ac_vec[3]),
        .ch_fault_latched(ch_fault_vec[3])
    );

    // ========================================================================
    // 保护电路
    // ========================================================================
    protection u_prot (
        .clk(clk), .rst_n(rst_n),
        .clear_fault(clear_fault_pulse), .otsd_auto_recovery(otsd_auto_recovery),
        .otw_raw(otw_raw_i), .otsd_raw(otsd_raw_i),
        .otw_ch_raw(otw_ch_raw_i), .otsd_ch_raw(otsd_ch_raw_i),
        .vbat_uv_raw(vbat_uv_raw_i), .vbat_ov_raw(vbat_ov_raw_i),
        .pvdd_uv_raw(pvdd_uv_raw_i), .pvdd_ov_raw(pvdd_ov_raw_i),
        .otw_int(otw_int), .otsd_int(otsd_int),
        .otw_ch_int(otw_ch_int), .otsd_ch_int(otsd_ch_int),
        .vbat_uv_int(vbat_uv_int), .vbat_ov_int(vbat_ov_int),
        .pvdd_uv_int(pvdd_uv_int), .pvdd_ov_int(pvdd_ov_int),
        .otsd_recovered(otsd_recovered)
    );

    // ========================================================================
    // 时钟监控器
    // ========================================================================
    clock_monitor u_clkm (
        .clk(clk), .rst_n(rst_n),
        .mclk_sync(mclk_i), .sclk_sync(sclk_i), .fsync_sync(fsync_i),
        .monitor_en(chip_active),
        .clock_lost(clock_lost), .mclk_lost(mclk_lost),
        .sclk_lost(sclk_lost), .fsync_lost(fsync_lost)
    );

    // ========================================================================
    // 故障监控器
    // ========================================================================
    fault_monitor u_fault (
        .clk(clk), .rst_n(rst_n),
        .clear_fault(clear_fault_pulse),
        .otw_int(otw_int), .otsd_int(otsd_int),
        .otw_ch_int(otw_ch_int), .otsd_ch_int(otsd_ch_int),
        .vbat_uv_int(vbat_uv_int), .vbat_ov_int(vbat_ov_int),
        .pvdd_uv_int(pvdd_uv_int), .pvdd_ov_int(pvdd_ov_int),
        .oc_ch(oc_ch_i), .dc_ch(dc_ch_i),
        .clock_lost(clock_lost), .por_vdd(por_vdd_i),
        .global_fault_irq(global_fault_irq), .ch_fault(ch_fault),
        .fault_trigger(fault_trigger), .warn_trigger(warn_trigger),
        .hw_ch_faults(), .hw_global_fault1(), .hw_global_fault2(), .hw_warnings(),
        .hw_wr_en(fm_hw_en), .hw_wr_addr(fm_hw_addr), .hw_wr_data(fm_hw_data)
    );

    // ========================================================================
    // DC诊断FSM
    // ========================================================================
    dc_diagnostic_fsm u_dc_diag (
        .clk(clk), .rst_n(rst_n),
        .any_ch_diag(any_ch_diag),
        .ac_fsm_busy(ac_fsm_busy),
        .dc_ldg_abort(1'b0),  // TODO: from 0x09[7]
        .ch_diag_active(ch_diag_vec),
        .ch_ac_active(ch_ac_vec),
        .s2g_ch(s2g_ch_i), .s2p_ch(s2p_ch_i), .sl_ch(sl_ch_i),
        .ol_ch(ol_ch_i), .lo_ch(lo_ch_i),
        .two_x_settle(dc_ramp_settle[0]),
        .diag_timeout_val(24'hFFFFF),
        .dc_diag_state(dc_diag_state),
        .dc_fsm_busy(dc_fsm_busy),
        .ch_diag_done(ch_diag_done),
        .dc_diag_rpt1(), .dc_diag_rpt2(), .dc_diag_rpt3(),
        .hw_wr_en(dc_hw_en), .hw_wr_addr(dc_hw_addr), .hw_wr_data(dc_hw_data)
    );

    // ========================================================================
    // AC诊断FSM
    // ========================================================================
    ac_diagnostic_fsm u_ac_diag (
        .clk(clk), .rst_n(rst_n),
        .any_ch_ac(any_ch_ac),
        .dc_fsm_busy(dc_fsm_busy),
        .ac_ldg_abort(1'b0),
        .ch_ac_active(ch_ac_vec),
        .ch_diag_active(ch_diag_vec),
        .ac_imp_ch0(8'd0), .ac_imp_ch1(8'd0), .ac_imp_ch2(8'd0), .ac_imp_ch3(8'd0),
        .ac_phase_val(16'd0), .ac_sti_val(16'd0),
        .ac_diag_ctrl1(8'd0), .ac_diag_ctrl2(8'd0),
        .ac_timeout_val(24'h80000),
        .ac_diag_state(ac_diag_state),
        .ac_fsm_busy(ac_fsm_busy),
        .ch_ac_done(ch_ac_done),
        .ac_diag_rpt_ch1(), .ac_diag_rpt_ch2(), .ac_diag_rpt_ch3(), .ac_diag_rpt_ch4(),
        .ac_phase_high(), .ac_phase_low(), .ac_sti_high(), .ac_sti_low(),
        .hw_wr_en(ac_hw_en), .hw_wr_addr(ac_hw_addr), .hw_wr_data(ac_hw_data)
    );

    // ========================================================================
    // 音频接口
    // ========================================================================
    audio_interface u_audio (
        .clk(clk), .rst_n(rst_n),
        .mclk_i(mclk_i), .sclk_i(sclk_i), .fsync_i(fsync_i),
        .sd_in1_i(sd_in1_i), .sd_in2_i(sd_in2_i),
        .sap_mode(sap_mode), .input_sr(input_sr),
        .tdm_slot_sel(tdm_slot_sel), .tdm_slot_size(tdm_slot_size),
        .ch_en_vec(ch_en_vec),
        .audio_data_ch1(audio_ch1), .audio_data_ch2(audio_ch2),
        .audio_data_ch3(audio_ch3), .audio_data_ch4(audio_ch4),
        .audio_valid(audio_valid)
    );

    // ========================================================================
    // PWM生成器
    // ========================================================================
    wire [2:0] output_phase;
    assign output_phase = {phase_sel_msb, output_phase_lsb};

    pwm_generator u_pwm (
        .clk(clk), .rst_n(rst_n),
        .audio_data_ch1(audio_ch1), .audio_data_ch2(audio_ch2),
        .audio_data_ch3(audio_ch3), .audio_data_ch4(audio_ch4),
        .audio_valid(audio_valid),
        .ch_en(ch_en_vec), .ch_mute_mode(ch_mute_vec),
        .ch_diag_active(ch_diag_vec), .ch_ac_active(ch_ac_vec),
        .input_sr(input_sr), .pwm_freq(pwm_freq), .output_phase(output_phase),
        .gain_level(gain_level), .pbtl_ch12(pbtl_ch12), .pbtl_ch34(pbtl_ch34),
        .oscillator_en(oscillator_en),
        .out_1p(out_1p_o), .out_1m(out_1m_o),
        .out_2p(out_2p_o), .out_2m(out_2m_o),
        .out_3p(out_3p_o), .out_3m(out_3m_o),
        .out_4p(out_4p_o), .out_4m(out_4m_o)
    );

endmodule
