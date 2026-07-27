// ============================================================================
// TAS6424E-Q1 诊断控制器 (封装层)
// 功能: 统一封装 DC诊断 / AC诊断 / 保护电路 / 故障监控 / 时钟监控
// 设计: 顶层仅例化一个模块, 内部协调5个子模块的信号流转
// ============================================================================

`include "tas6424e_defines.vh"

module diagnostic_ctrl (
    input  wire         clk,
    input  wire         rst_n,
    // ---- 控制 ----
    input  wire         chip_active,        // 芯片激活
    input  wire         clear_fault_pulse,  // 0x21 bit7 清除故障
    input  wire         dc_ldg_abort,       // 0x09 bit7 中止DC诊断
    input  wire         ldg_bypass,         // 0x09 bit0 禁止自动诊断
    input  wire         otsd_auto_recovery, // 0x21 bit3 OTSD自动恢复
    input  wire [1:0]   dc_ramp_settle,     // 0x09 bit6:5 诊断时序
    input  wire [7:0]   pin_ctrl,           // 0x14 引脚控制
    // ---- 通道状态 (来自channel_fsm) ----
    input  wire [3:0]   ch_diag_active,     // DC诊断激活
    input  wire [3:0]   ch_ac_active,       // AC诊断激活
    // ---- 诊断完成输出 → 通道FSM ----
    output wire [3:0]   ch_diag_done,       // DC诊断完成
    output wire [3:0]   ch_ac_done,         // AC诊断完成
    // ---- 诊断触发输入 ----
    input  wire         any_ch_diag,        // 任意通道DC诊断
    input  wire         any_ch_ac,          // 任意通道AC诊断
    // ---- 模拟前端诊断输入 ----
    input  wire [3:0]   s2g_ch_i, s2p_ch_i, sl_ch_i, ol_ch_i, lo_ch_i,
    // ---- 模拟前端故障输入 ----
    input  wire         otw_raw_i, otsd_raw_i,
    input  wire [3:0]   otw_ch_raw_i, otsd_ch_raw_i,
    input  wire         vbat_uv_raw_i, vbat_ov_raw_i,
    input  wire         pvdd_uv_raw_i, pvdd_ov_raw_i,
    input  wire [3:0]   oc_ch_i, dc_ch_i,
    input  wire         por_vdd_i,
    // ---- 时钟输入 (异步, 内部CDC) ----
    input  wire         mclk_i, sclk_i, fsync_i,
    // ---- 故障/警告输出 ----
    output wire         global_fault_irq,   // 全局故障 (→channel_fsm)
    output wire [3:0]   ch_fault,           // 通道故障 (→channel_fsm)
    output wire         fault_trigger,      // FAULT引脚
    output wire         warn_trigger,       // WARN引脚
    // ---- 硬件写 → 仲裁器 ----
    output wire         diag_hw_en,
    output wire [7:0]   diag_hw_addr,
    output wire [7:0]   diag_hw_data,
    output wire         fault_hw_en,
    output wire [7:0]   fault_hw_addr,
    output wire [7:0]   fault_hw_data,
    // ---- 寄存器报告 (内部只读, 无需外部) ----
    output wire [7:0]   dc_diag_rpt1,
    output wire [7:0]   dc_diag_rpt2,
    output wire [7:0]   dc_diag_rpt3,
    output wire [7:0]   ac_diag_rpt_ch1, ac_diag_rpt_ch2,
    output wire [7:0]   ac_diag_rpt_ch3, ac_diag_rpt_ch4,
    output wire [7:0]   ac_phase_high, ac_phase_low,
    output wire [7:0]   ac_sti_high, ac_sti_low,
    // ---- AC诊断模拟前端输入 ----
    input  wire [7:0]   ac_imp_ch0,         // CH1 AC阻抗测量值
    input  wire [7:0]   ac_imp_ch1,         // CH2
    input  wire [7:0]   ac_imp_ch2,         // CH3
    input  wire [7:0]   ac_imp_ch3,         // CH4
    input  wire [15:0]  ac_phase_val,       // 相位测量值 (16bit)
    input  wire [15:0]  ac_sti_val,         // 刺激值 (16bit)
    // ---- 时钟丢失 ----
    output wire         clock_lost,
    // ---- 保护状态 ----
    output wire         otsd_recovered
);

    // ========================================================================
    // 内部信号: 子模块间互联
    // ========================================================================

    // 保护电路 → 故障监控
    wire       otw_int, otsd_int;
    wire [3:0] otw_ch_int, otsd_ch_int;
    wire       vbat_uv_int, vbat_ov_int, pvdd_uv_int, pvdd_ov_int;

    // DC诊断 → 硬件写
    wire [7:0] dc_hw_addr, dc_hw_data;
    wire       dc_hw_en;

    // AC诊断 → 硬件写
    wire [7:0] ac_hw_addr, ac_hw_data;
    wire       ac_hw_en;

    // 时钟监控
    wire mclk_lost, sclk_lost, fsync_lost;

    // FSM互斥
    wire dc_fsm_busy, ac_fsm_busy;

    // ========================================================================
    //  1. 保护电路: 故障信号去毛刺 + OTSD恢复
    // ========================================================================
    protection u_prot (
        .clk(clk), .rst_n(rst_n),
        .clear_fault(clear_fault_pulse),
        .otsd_auto_recovery(otsd_auto_recovery),
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
    //  2. 时钟监控器: MCLK/SCLK/FSYNC活动检测
    // ========================================================================
    clock_monitor u_clkm (
        .clk(clk), .rst_n(rst_n),
        .mclk_i(mclk_i), .sclk_i(sclk_i), .fsync_i(fsync_i),
        .monitor_en(chip_active),
        .clock_lost(clock_lost),
        .mclk_lost(mclk_lost), .sclk_lost(sclk_lost), .fsync_lost(fsync_lost)
    );

    // ========================================================================
    //  3. 故障监控器: 锁存+编码+中断
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
        .hw_wr_en(fault_hw_en), .hw_wr_addr(fault_hw_addr), .hw_wr_data(fault_hw_data)
    );

    // ========================================================================
    //  4. DC诊断FSM
    // ========================================================================
    dc_diagnostic_fsm u_dc_diag (
        .clk(clk), .rst_n(rst_n),
        .any_ch_diag(any_ch_diag), .ac_fsm_busy(ac_fsm_busy),
        .dc_ldg_abort(dc_ldg_abort),
        .ch_diag_active(ch_diag_active), .ch_ac_active(ch_ac_active),
        .s2g_ch(s2g_ch_i), .s2p_ch(s2p_ch_i), .sl_ch(sl_ch_i),
        .ol_ch(ol_ch_i), .lo_ch(lo_ch_i),
        .two_x_settle(dc_ramp_settle[0]),
        .diag_timeout_val(DIAG_TIMEOUT_VAL),
        .dc_diag_state(), .dc_fsm_busy(dc_fsm_busy),
        .ch_diag_done(ch_diag_done),
        .dc_diag_rpt1(dc_diag_rpt1), .dc_diag_rpt2(dc_diag_rpt2), .dc_diag_rpt3(dc_diag_rpt3),
        .hw_wr_en(dc_hw_en), .hw_wr_addr(dc_hw_addr), .hw_wr_data(dc_hw_data)
    );

    // ========================================================================
    //  5. AC诊断FSM
    // ========================================================================
    ac_diagnostic_fsm u_ac_diag (
        .clk(clk), .rst_n(rst_n),
        .any_ch_ac(any_ch_ac), .dc_fsm_busy(dc_fsm_busy),
        .ac_ldg_abort(dc_ldg_abort),
        .ch_ac_active(ch_ac_active), .ch_diag_active(ch_diag_active),
        .ac_imp_ch0(ac_imp_ch0), .ac_imp_ch1(ac_imp_ch1),
        .ac_imp_ch2(ac_imp_ch2), .ac_imp_ch3(ac_imp_ch3),
        .ac_phase_val(ac_phase_val), .ac_sti_val(ac_sti_val),
        .ac_diag_ctrl1(8'd0), .ac_diag_ctrl2(8'd0),  // TODO: 连接0x15/0x16
        .ac_timeout_val(DIAG_TIMEOUT_VAL),
        .ac_diag_state(), .ac_fsm_busy(ac_fsm_busy),
        .ch_ac_done(ch_ac_done),
        .ac_diag_rpt_ch1(ac_diag_rpt_ch1), .ac_diag_rpt_ch2(ac_diag_rpt_ch2),
        .ac_diag_rpt_ch3(ac_diag_rpt_ch3), .ac_diag_rpt_ch4(ac_diag_rpt_ch4),
        .ac_phase_high(ac_phase_high), .ac_phase_low(ac_phase_low),
        .ac_sti_high(ac_sti_high), .ac_sti_low(ac_sti_low),
        .hw_wr_en(ac_hw_en), .hw_wr_addr(ac_hw_addr), .hw_wr_data(ac_hw_data)
    );

    // ========================================================================
    //  6. 诊断硬件写仲裁 (DC + AC → 单一diag_hw输出)
    // ========================================================================
    assign diag_hw_en   = dc_hw_en | ac_hw_en;
    assign diag_hw_addr = dc_hw_en ? dc_hw_addr : ac_hw_addr;
    assign diag_hw_data = dc_hw_en ? dc_hw_data : ac_hw_data;

endmodule
