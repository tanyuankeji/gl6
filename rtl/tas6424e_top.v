// ============================================================================
// TAS6424E-Q1 顶层集成模块
// 功能: 集成所有子模块, 56引脚接口
// 结构: 6个功能域 (控制域 / 配置域 / 通道域 / 诊断域 / 音频域 / 保护域)
// ============================================================================

`include "tas6424e_defines.vh"

module tas6424e_top (
    // 系统信号
    input  wire         clk,
    input  wire         rst_n,
    // I2C接口
    input  wire         scl_i,
    inout  wire         sda_io,
    input  wire [1:0]   i2c_addr_i,
    // 音频接口
    input  wire         mclk_i, sclk_i, fsync_i,
    input  wire         sd_in1_i, sd_in2_i,
    // 硬件控制引脚
    input  wire         standby_n_i, mute_n_i,
    output wire         fault_n_o, warn_n_o,
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
    // 模拟前端诊断输入 (DC诊断)
    input  wire [3:0]   s2g_ch_i, s2p_ch_i, ol_ch_i, sl_ch_i, lo_ch_i,
    // 模拟前端诊断输入 (AC诊断)
    input  wire [7:0]   ac_imp_ch0, ac_imp_ch1, ac_imp_ch2, ac_imp_ch3,
    input  wire [15:0]  ac_phase_val, ac_sti_val
);

    // ========================================================================
    //  1. 控制域: 顶层控制器 + 引脚控制
    // ========================================================================

    wire       por_done;
    wire       standby_n_db, mute_n_db;
    wire [1:0] chip_state;
    wire       chip_active, oscillator_en;
    wire       any_ch_play, any_ch_mute, all_ch_hiz, any_ch_diag, any_ch_ac;

    assign por_done = !por_vdd_i;  // POR=1异常, 0正常

    pin_control u_pin (
        .clk(clk), .rst_n(rst_n),
        .standby_n_i(standby_n_i), .mute_n_i(mute_n_i),
        .fault_trigger(fault_trigger), .warn_trigger(warn_trigger),
        .pin_ctrl(pin_ctrl),
        .fault_n_o(fault_n_o), .warn_n_o(warn_n_o),
        .standby_n_db(standby_n_db), .mute_n_db(mute_n_db)
    );

    chip_top_controller u_top (
        .clk(clk), .rst_n(rst_n),
        .por_done(por_done), .standby_n_db(standby_n_db),
        .chip_state(chip_state), .chip_active(chip_active),
        .oscillator_en(oscillator_en),
        .ch0_state(ch_state_vec[0]), .ch1_state(ch_state_vec[1]),
        .ch2_state(ch_state_vec[2]), .ch3_state(ch_state_vec[3]),
        .any_ch_play(any_ch_play), .any_ch_mute(any_ch_mute),
        .all_ch_hiz(all_ch_hiz), .any_ch_diag(any_ch_diag), .any_ch_ac(any_ch_ac)
    );

    // ========================================================================
    //  2. 配置域: I2C从机 + 寄存器文件
    // ========================================================================

    wire       reg_wr_en, reg_rd_en;
    wire [7:0] reg_wr_addr, reg_wr_data, reg_rd_addr, reg_rd_data;
    wire       hw_wr_en;
    wire [7:0] hw_wr_addr, hw_wr_data;

    // 寄存器配置输出 (按功能分类)
    // 控制类
    wire       soft_reset, clear_fault_pulse, dc_ldg_abort, ldg_bypass;
    // 音频类
    wire       hpf_bypass, tdm_slot_sel, tdm_slot_size;
    wire [2:0] sap_mode;
    wire [1:0] input_sr;
    // 通道类
    wire [7:0] ch_state_ctrl;
    wire [3:0] ac_diag_en;
    // PWM类
    wire [2:0] pwm_freq;
    wire [1:0] output_phase_lsb, gain_level;
    wire       pbtl_ch12, pbtl_ch34, phase_sel_msb;
    // 保护类
    wire [7:0] pin_ctrl;
    wire       oc_level, otsd_auto_recovery, ldg_lo_enable;
    wire [1:0] dc_ramp_settle, otw_threshold, volume_rate;

    i2c_slave u_i2c (
        .clk(clk), .rst_n(rst_n),
        .scl_i(scl_i), .sda_io(sda_io), .i2c_addr_i(i2c_addr_i),
        .reg_wr_en(reg_wr_en), .reg_wr_addr(reg_wr_addr), .reg_wr_data(reg_wr_data),
        .reg_rd_en(reg_rd_en), .reg_rd_addr(reg_rd_addr), .reg_rd_data(reg_rd_data)
    );

    register_file u_reg (
        .clk(clk), .rst_n(rst_n),
        .reg_wr_en(reg_wr_en), .reg_wr_addr(reg_wr_addr), .reg_wr_data(reg_wr_data),
        .reg_rd_en(reg_rd_en), .reg_rd_addr(reg_rd_addr), .reg_rd_data(reg_rd_data),
        .hw_wr_addr(hw_wr_addr), .hw_wr_data(hw_wr_data), .hw_wr_en(hw_wr_en),
        .soft_reset(soft_reset), .clear_fault_pulse(clear_fault_pulse),
        .dc_ldg_abort(dc_ldg_abort), .ldg_bypass(ldg_bypass),
        .hpf_bypass(hpf_bypass), .tdm_slot_sel(tdm_slot_sel),
        .tdm_slot_size(tdm_slot_size), .sap_mode(sap_mode), .input_sr(input_sr),
        .ch_state_ctrl(ch_state_ctrl), .ac_diag_en(ac_diag_en),
        .pwm_freq(pwm_freq), .output_phase_lsb(output_phase_lsb),
        .gain_level(gain_level), .pbtl_ch12(pbtl_ch12), .pbtl_ch34(pbtl_ch34),
        .phase_sel_msb(phase_sel_msb),
        .pin_ctrl(pin_ctrl), .oc_level(oc_level),
        .otsd_auto_recovery(otsd_auto_recovery), .ldg_lo_enable(ldg_lo_enable),
        .dc_ramp_settle(dc_ramp_settle), .otw_threshold(otw_threshold),
        .volume_rate(volume_rate)
    );

    // ========================================================================
    //  3. 通道域: 4通道FSM (generate循环)
    // ========================================================================

    // 通道状态向量
    wire [2:0] ch_state_vec [0:3];
    wire [3:0] ch_en_vec, ch_mute_vec, ch_diag_vec, ch_ac_vec, ch_fault_vec;
    wire [3:0] ch_diag_done, ch_ac_done;
    wire       global_fault_irq;
    wire [3:0] ch_fault;

    // 0x04寄存器 → 每通道2bit分配
    wire [1:0] ch_state_req [0:3];
    assign ch_state_req[0] = ch_state_ctrl[1:0];
    assign ch_state_req[1] = ch_state_ctrl[3:2];
    assign ch_state_req[2] = ch_state_ctrl[5:4];
    assign ch_state_req[3] = ch_state_ctrl[7:6];

    // ========================================================================
    // 0x0F上报 (函数: ch_state → datasheet编码, 定义在此处)
    // ========================================================================
    function [1:0] ch_state_to_ds;
        input [2:0] state;
        case (state)
            CH_PLAY:          ch_state_to_ds = 2'b00;
            CH_HIGH_Z:        ch_state_to_ds = 2'b01;
            CH_MUTE:          ch_state_to_ds = 2'b10;
            CH_DC_DIAG_ENTRY: ch_state_to_ds = 2'b11;
            CH_AC_DIAG_ENTRY: ch_state_to_ds = 2'b01;
            default:          ch_state_to_ds = 2'b01;
        endcase
    endfunction

    // 0x0F上报 (ch_state_to_ds在defines.vh中)
    wire [7:0] ch_state_report;
    assign ch_state_report = {ch_state_to_ds(ch_state_vec[3]),
                              ch_state_to_ds(ch_state_vec[2]),
                              ch_state_to_ds(ch_state_vec[1]),
                              ch_state_to_ds(ch_state_vec[0])};

    // 0x0F硬件写入 (状态变化时触发)
    reg [7:0] ch_state_shadow;
    reg       ch_state_hw_wr;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) {ch_state_shadow, ch_state_hw_wr} <= {8'd0, 1'b0};
        else begin
            ch_state_hw_wr <= 1'b0;
            if (ch_state_report != ch_state_shadow) begin
                ch_state_shadow <= ch_state_report;
                ch_state_hw_wr  <= 1'b1;
            end
        end
    end
    wire       ch_state_wr_en   = ch_state_hw_wr;
    wire [7:0] ch_state_wr_addr = 8'h0F;
    wire [7:0] ch_state_wr_data = ch_state_report;

    genvar ci;
    generate
        for (ci = 0; ci < 4; ci = ci + 1) begin : gen_channel
            channel_fsm #(.CHANNEL_ID(ci)) u_ch (
                .clk(clk), .rst_n(rst_n),
                .chip_active(chip_active),
                .global_fault(global_fault_irq),
                .clear_fault(clear_fault_pulse),
                .ch_state_req(ch_state_req[ci]),
                .ldg_bypass(ldg_bypass),
                .ac_diag_en(ac_diag_en[ci]),
                .hw_mute_n(mute_n_db),
                .ch_fault(ch_fault[ci]),
                .ch_diag_done(ch_diag_done[ci]),
                .ch_ac_done(ch_ac_done[ci]),
                .dc_ldg_abort(dc_ldg_abort),
                .ch_state(ch_state_vec[ci]),
                .ch_en(ch_en_vec[ci]),
                .ch_mute_mode(ch_mute_vec[ci]),
                .ch_diag_active(ch_diag_vec[ci]),
                .ch_ac_active(ch_ac_vec[ci]),
                .ch_fault_latched(ch_fault_vec[ci])
            );
        end
    endgenerate

    // ========================================================================
    //  4. 诊断域: 诊断控制器 (封装 DC/AC/保护/故障/时钟 为单一层)
    // ========================================================================

    wire       clock_lost;
    wire       fault_trigger, warn_trigger;
    wire [7:0] diag_hw_addr, diag_hw_data, fault_hw_addr, fault_hw_data;
    wire       diag_hw_en, fault_hw_en;

    diagnostic_ctrl u_diag_ctrl (
        .clk(clk), .rst_n(rst_n),
        .chip_active(chip_active),
        .clear_fault_pulse(clear_fault_pulse),
        .dc_ldg_abort(dc_ldg_abort),
        .ldg_bypass(ldg_bypass),
        .otsd_auto_recovery(otsd_auto_recovery),
        .dc_ramp_settle(dc_ramp_settle),
        .pin_ctrl(pin_ctrl),
        .ch_diag_active(ch_diag_vec), .ch_ac_active(ch_ac_vec),
        .ch_diag_done(ch_diag_done), .ch_ac_done(ch_ac_done),
        .any_ch_diag(any_ch_diag), .any_ch_ac(any_ch_ac),
        .s2g_ch_i(s2g_ch_i), .s2p_ch_i(s2p_ch_i), .sl_ch_i(sl_ch_i),
        .ol_ch_i(ol_ch_i), .lo_ch_i(lo_ch_i),
        .otw_raw_i(otw_raw_i), .otsd_raw_i(otsd_raw_i),
        .otw_ch_raw_i(otw_ch_raw_i), .otsd_ch_raw_i(otsd_ch_raw_i),
        .vbat_uv_raw_i(vbat_uv_raw_i), .vbat_ov_raw_i(vbat_ov_raw_i),
        .pvdd_uv_raw_i(pvdd_uv_raw_i), .pvdd_ov_raw_i(pvdd_ov_raw_i),
        .oc_ch_i(oc_ch_i), .dc_ch_i(dc_ch_i),
        .por_vdd_i(por_vdd_i),
        .mclk_i(mclk_i), .sclk_i(sclk_i), .fsync_i(fsync_i),
        .ac_imp_ch0(ac_imp_ch0), .ac_imp_ch1(ac_imp_ch1),
        .ac_imp_ch2(ac_imp_ch2), .ac_imp_ch3(ac_imp_ch3),
        .ac_phase_val(ac_phase_val), .ac_sti_val(ac_sti_val),
        .global_fault_irq(global_fault_irq), .ch_fault(ch_fault),
        .fault_trigger(fault_trigger), .warn_trigger(warn_trigger),
        .diag_hw_en(diag_hw_en), .diag_hw_addr(diag_hw_addr), .diag_hw_data(diag_hw_data),
        .fault_hw_en(fault_hw_en), .fault_hw_addr(fault_hw_addr), .fault_hw_data(fault_hw_data),
        .dc_diag_rpt1(), .dc_diag_rpt2(), .dc_diag_rpt3(),
        .ac_diag_rpt_ch1(), .ac_diag_rpt_ch2(), .ac_diag_rpt_ch3(), .ac_diag_rpt_ch4(),
        .ac_phase_high(), .ac_phase_low(), .ac_sti_high(), .ac_sti_low(),
        .clock_lost(clock_lost), .otsd_recovered()
    );

    // ========================================================================
    //  5. 音频域: 音频接口 + PWM生成器
    // ========================================================================

    wire [23:0] audio_ch1, audio_ch2, audio_ch3, audio_ch4;
    wire        audio_valid;

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

    // ========================================================================
    //  6. 硬件写仲裁
    // ========================================================================

    hw_write_arbiter u_hw_arb (
        .ch_state_wr_en(ch_state_wr_en),
        .ch_state_wr_addr(ch_state_wr_addr),
        .ch_state_wr_data(ch_state_wr_data),
        .diag_hw_en(diag_hw_en),
        .diag_hw_addr(diag_hw_addr),
        .diag_hw_data(diag_hw_data),
        .fault_hw_en(fault_hw_en),
        .fault_hw_addr(fault_hw_addr),
        .fault_hw_data(fault_hw_data),
        .hw_wr_en(hw_wr_en), .hw_wr_addr(hw_wr_addr), .hw_wr_data(hw_wr_data)
    );

endmodule
