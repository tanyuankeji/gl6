/**
 * Module: tas6424e_top
 * Description: TAS6424E-Q1 顶层模块
 *              集成所有子模块：I2C从机、寄存器文件、状态机、通道状态机、
 *              音频接口、PWM生成器、诊断控制器、故障监控器、
 *              引脚控制、时钟监控、保护电路
 *
 * Author: AI Designer
 * Date: 2026-07-11
 * Version: 1.0.0
 *
 * Parameters:
 *   - CLK_FREQ: 系统时钟频率Hz（默认10MHz）
 *
 * Ports:
 *   - 见设计规格文档中的引脚定义
 */

`timescale 1ns/1ps

`include "tas6424e_defines.v"

module tas6424e_top #(
    parameter CLK_FREQ = 10_000_000
) (
    input  wire        clk,                // 系统时钟
    input  wire        rst_n,              // 异步复位
    input  wire        pad_rst_n,          // POR复位

    // I2C接口
    inout  wire        i2c_scl,            // I2C时钟线
    inout  wire        i2c_sda,            // I2C数据线
    input  wire        i2c_addr1,          // I2C地址选择1
    input  wire        i2c_addr0,          // I2C地址选择0

    // 音频接口
    input  wire        mclk,               // 音频主时钟
    input  wire        sclk,               // 位时钟
    input  wire        fsync,              // 帧同步
    input  wire        sdin1,              // 数据输入1
    input  wire        sdin2,              // 数据输入2

    // 控制引脚
    input  wire        standby_n_pin,      // STANDBY引脚（低有效）
    input  wire        mute_n_pin,         // MUTE引脚（低有效）
    output wire        fault_n,            // FAULT引脚（开漏低有效）
    output wire        warn_n,             // WARN引脚（开漏低有效）

    // PWM输出（4通道BTL）
    output wire        out_1p, output wire out_1m,
    output wire        out_2p, output wire out_2m,
    output wire        out_3p, output wire out_3m,
    output wire        out_4p, output wire out_4m,

    // 模拟前端故障输入
    input  wire        otw_raw,            // 过温警告
    input  wire        otsd_raw,           // 过温关断
    input  wire        vbat_uv_raw,        // VBAT欠压
    input  wire        vbat_ov_raw,        // VBAT过压
    input  wire        pvdd_uv_raw,        // PVDD欠压
    input  wire        pvdd_ov_raw,        // PVDD过压
    input  wire        oc_ch1,             // 通道1过流
    input  wire        oc_ch2,             // 通道2过流
    input  wire        oc_ch3,             // 通道3过流
    input  wire        oc_ch4,             // 通道4过流
    input  wire        dc_ch1,             // 通道1直流检测
    input  wire        dc_ch2,             // 通道2直流检测
    input  wire        dc_ch3,             // 通道3直流检测
    input  wire        dc_ch4              // 通道4直流检测
);

    //----------------------------------------------------------
    // 内部信号：I2C总线三态控制
    //----------------------------------------------------------
    wire        i2c_scl_i = i2c_scl;       // SCL输入
    wire        i2c_sda_i = i2c_sda;       // SDA输入
    wire        i2c_sda_o;                 // SDA输出
    wire        i2c_sda_oe;                // SDA输出使能

    // SDA三态驱动
    assign i2c_sda = i2c_sda_oe ? i2c_sda_o : 1'bz;

    //----------------------------------------------------------
    // 内部信号：I2C到寄存器文件接口
    //----------------------------------------------------------
    wire        reg_wr_en;
    wire [7:0]  reg_wr_addr;
    wire [7:0]  reg_wr_data;
    wire        reg_rd_en;
    wire [7:0]  reg_rd_addr;
    wire [7:0]  reg_rd_data;

    //----------------------------------------------------------
    // 内部信号：寄存器文件输出
    //----------------------------------------------------------
    wire [7:0]  reg_mode_ctrl;
    wire [7:0]  reg_misc_ctrl1;
    wire [7:0]  reg_misc_ctrl2;
    wire [7:0]  reg_sap_ctrl;
    wire [7:0]  reg_ch_state_ctrl;
    wire [7:0]  reg_ch1_vol;
    wire [7:0]  reg_ch2_vol;
    wire [7:0]  reg_ch3_vol;
    wire [7:0]  reg_ch4_vol;
    wire [7:0]  reg_dc_diag_ctrl1;
    wire [7:0]  reg_dc_diag_ctrl2;
    wire [7:0]  reg_dc_diag_ctrl3;
    wire [7:0]  reg_pin_ctrl;
    wire [7:0]  reg_ac_diag_ctrl1;
    wire [7:0]  reg_ac_diag_ctrl2;
    wire [7:0]  reg_misc_ctrl3;
    wire [7:0]  reg_clip_ctrl;
    wire [7:0]  reg_clip_window;
    wire [7:0]  reg_misc_ctrl4;
    wire [7:0]  reg_misc_ctrl5;
    wire [7:0]  reg_ss_ctrl1;
    wire [7:0]  reg_ss_ctrl2;
    wire [7:0]  reg_ss_ctrl3;

    wire        soft_reset;
    wire        clear_fault;
    wire        otsd_auto_recovery;

    //----------------------------------------------------------
    // 内部信号：硬件写入寄存器
    //----------------------------------------------------------
    wire [7:0]  hw_dc_diag_rpt1;
    wire [7:0]  hw_dc_diag_rpt2;
    wire [7:0]  hw_dc_diag_rpt3;
    wire [7:0]  hw_ch_state_rpt;
    wire [7:0]  hw_ch_faults;
    wire [7:0]  hw_global_fault1;
    wire [7:0]  hw_global_fault2;
    wire [7:0]  hw_warnings;
    wire [7:0]  hw_ac_diag_rpt_ch1;
    wire [7:0]  hw_ac_diag_rpt_ch2;
    wire [7:0]  hw_ac_diag_rpt_ch3;
    wire [7:0]  hw_ac_diag_rpt_ch4;
    wire [7:0]  hw_clip_warning;
    wire [7:0]  hw_ilimit_status;

    //----------------------------------------------------------
    // 内部信号：状态机
    //----------------------------------------------------------
    wire [2:0]  chip_state;
    wire        diag_trigger;

    //----------------------------------------------------------
    // 内部信号：通道状态机
    //----------------------------------------------------------
    wire [1:0]  ch1_state, ch2_state, ch3_state, ch4_state;
    wire        ch1_en, ch2_en, ch3_en, ch4_en;
    wire        ch1_mute, ch2_mute, ch3_mute, ch4_mute;
    wire        ch1_diag_active, ch2_diag_active, ch3_diag_active, ch4_diag_active;
    wire        ch1_fault, ch2_fault, ch3_fault, ch4_fault;

    //----------------------------------------------------------
    // 内部信号：音频接口
    //----------------------------------------------------------
    wire [23:0] audio_data_ch1;
    wire [23:0] audio_data_ch2;
    wire [23:0] audio_data_ch3;
    wire [23:0] audio_data_ch4;
    wire        audio_valid;

    //----------------------------------------------------------
    // 内部信号：诊断
    //----------------------------------------------------------
    wire        diag_done;
    wire [3:0]  ch_diag_active = {ch4_diag_active, ch3_diag_active,
                                   ch2_diag_active, ch1_diag_active};

    //----------------------------------------------------------
    // 内部信号：故障监控
    //----------------------------------------------------------
    wire        global_fault_irq;
    wire        any_ch_fault = ch1_fault | ch2_fault | ch3_fault | ch4_fault;

    //----------------------------------------------------------
    // 内部信号：时钟监控
    //----------------------------------------------------------
    wire        clock_lost;

    //----------------------------------------------------------
    // 内部信号：保护电路
    //----------------------------------------------------------
    wire        otw_int;
    wire        otsd_int;
    wire        vbat_uv_int;
    wire        vbat_ov_int;
    wire        pvdd_uv_int;
    wire        pvdd_ov_int;

    //----------------------------------------------------------
    // 内部信号：引脚控制
    //----------------------------------------------------------
    wire        standby_n_int;
    wire        mute_n_int;

    //----------------------------------------------------------
    // 通道状态报告组装
    //----------------------------------------------------------
    assign hw_ch_state_rpt = {ch4_state, ch3_state, ch2_state, ch1_state};

    // clip_warning和ilimit_status默认值（简化）
    assign hw_clip_warning   = 8'h00;
    assign hw_ilimit_status  = 8'h00;

    // POR标志来自warnings寄存器bit5
    wire por_flag = hw_warnings[5];

    // OTW警告
    wire otw_warning = hw_warnings[4];

    //==========================================================
    // 模块实例化
    //==========================================================

    //----------------------------------------------------------
    // I2C从机
    //----------------------------------------------------------
    i2c_slave #(
        .CLK_FREQ(CLK_FREQ)
    ) u_i2c_slave (
        .clk        (clk),
        .rst_n      (rst_n),
        .scl        (i2c_scl_i),
        .sda_i      (i2c_sda_i),
        .sda_o      (i2c_sda_o),
        .sda_oe     (i2c_sda_oe),
        .i2c_addr1  (i2c_addr1),
        .i2c_addr0  (i2c_addr0),
        .reg_wr_en  (reg_wr_en),
        .reg_wr_addr(reg_wr_addr),
        .reg_wr_data(reg_wr_data),
        .reg_rd_en  (reg_rd_en),
        .reg_rd_addr(reg_rd_addr),
        .reg_rd_data(reg_rd_data)
    );

    //----------------------------------------------------------
    // 寄存器文件
    //----------------------------------------------------------
    register_file u_register_file (
        .clk                (clk),
        .rst_n              (rst_n),
        .pad_rst_n          (pad_rst_n),
        .i2c_wr_en          (reg_wr_en),
        .i2c_wr_addr        (reg_wr_addr),
        .i2c_wr_data        (reg_wr_data),
        .i2c_rd_en          (reg_rd_en),
        .i2c_rd_addr        (reg_rd_addr),
        .i2c_rd_data        (reg_rd_data),
        .reg_mode_ctrl      (reg_mode_ctrl),
        .reg_misc_ctrl1     (reg_misc_ctrl1),
        .reg_misc_ctrl2     (reg_misc_ctrl2),
        .reg_sap_ctrl       (reg_sap_ctrl),
        .reg_ch_state_ctrl  (reg_ch_state_ctrl),
        .reg_ch1_vol        (reg_ch1_vol),
        .reg_ch2_vol        (reg_ch2_vol),
        .reg_ch3_vol        (reg_ch3_vol),
        .reg_ch4_vol        (reg_ch4_vol),
        .reg_dc_diag_ctrl1  (reg_dc_diag_ctrl1),
        .reg_dc_diag_ctrl2  (reg_dc_diag_ctrl2),
        .reg_dc_diag_ctrl3  (reg_dc_diag_ctrl3),
        .reg_pin_ctrl       (reg_pin_ctrl),
        .reg_ac_diag_ctrl1  (reg_ac_diag_ctrl1),
        .reg_ac_diag_ctrl2  (reg_ac_diag_ctrl2),
        .reg_misc_ctrl3     (reg_misc_ctrl3),
        .reg_clip_ctrl      (reg_clip_ctrl),
        .reg_clip_window    (reg_clip_window),
        .reg_misc_ctrl4     (reg_misc_ctrl4),
        .reg_misc_ctrl5     (reg_misc_ctrl5),
        .reg_ss_ctrl1       (reg_ss_ctrl1),
        .reg_ss_ctrl2       (reg_ss_ctrl2),
        .reg_ss_ctrl3       (reg_ss_ctrl3),
        .hw_dc_diag_rpt1    (hw_dc_diag_rpt1),
        .hw_dc_diag_rpt2    (hw_dc_diag_rpt2),
        .hw_dc_diag_rpt3    (hw_dc_diag_rpt3),
        .hw_ch_state_rpt    (hw_ch_state_rpt),
        .hw_ch_faults       (hw_ch_faults),
        .hw_global_fault1   (hw_global_fault1),
        .hw_global_fault2   (hw_global_fault2),
        .hw_warnings        (hw_warnings),
        .hw_ac_diag_rpt_ch1 (hw_ac_diag_rpt_ch1),
        .hw_ac_diag_rpt_ch2 (hw_ac_diag_rpt_ch2),
        .hw_ac_diag_rpt_ch3 (hw_ac_diag_rpt_ch3),
        .hw_ac_diag_rpt_ch4 (hw_ac_diag_rpt_ch4),
        .hw_clip_warning    (hw_clip_warning),
        .hw_ilimit_status   (hw_ilimit_status),
        .soft_reset         (soft_reset),
        .clear_fault        (clear_fault),
        .otsd_auto_recovery (otsd_auto_recovery)
    );

    //----------------------------------------------------------
    // 主状态机
    //----------------------------------------------------------
    state_machine u_state_machine (
        .clk            (clk),
        .rst_n          (rst_n),
        .pad_rst_n      (pad_rst_n),
        .standby_n      (standby_n_int),
        .ch_state_ctrl  (reg_ch_state_ctrl),
        .global_fault   (global_fault_irq),
        .diag_done      (diag_done),
        .clear_fault    (clear_fault),
        .chip_state     (chip_state),
        .diag_trigger   (diag_trigger)
    );

    //----------------------------------------------------------
    // 通道状态机（4个实例）
    //----------------------------------------------------------
    channel_fsm u_ch1_fsm (
        .clk            (clk),
        .rst_n          (rst_n),
        .chip_state     (chip_state),
        .ch_state_req   (reg_ch_state_ctrl[1:0]),
        .ch_fault       (ch1_fault),
        .clear_fault    (clear_fault),
        .diag_trigger   (diag_trigger),
        .diag_done      (diag_done),
        .ch_state       (ch1_state),
        .ch_en          (ch1_en),
        .ch_mute_mode   (ch1_mute),
        .ch_diag_active (ch1_diag_active)
    );

    channel_fsm u_ch2_fsm (
        .clk            (clk),
        .rst_n          (rst_n),
        .chip_state     (chip_state),
        .ch_state_req   (reg_ch_state_ctrl[3:2]),
        .ch_fault       (ch2_fault),
        .clear_fault    (clear_fault),
        .diag_trigger   (diag_trigger),
        .diag_done      (diag_done),
        .ch_state       (ch2_state),
        .ch_en          (ch2_en),
        .ch_mute_mode   (ch2_mute),
        .ch_diag_active (ch2_diag_active)
    );

    channel_fsm u_ch3_fsm (
        .clk            (clk),
        .rst_n          (rst_n),
        .chip_state     (chip_state),
        .ch_state_req   (reg_ch_state_ctrl[5:4]),
        .ch_fault       (ch3_fault),
        .clear_fault    (clear_fault),
        .diag_trigger   (diag_trigger),
        .diag_done      (diag_done),
        .ch_state       (ch3_state),
        .ch_en          (ch3_en),
        .ch_mute_mode   (ch3_mute),
        .ch_diag_active (ch3_diag_active)
    );

    channel_fsm u_ch4_fsm (
        .clk            (clk),
        .rst_n          (rst_n),
        .chip_state     (chip_state),
        .ch_state_req   (reg_ch_state_ctrl[7:6]),
        .ch_fault       (ch4_fault),
        .clear_fault    (clear_fault),
        .diag_trigger   (diag_trigger),
        .diag_done      (diag_done),
        .ch_state       (ch4_state),
        .ch_en          (ch4_en),
        .ch_mute_mode   (ch4_mute),
        .ch_diag_active (ch4_diag_active)
    );

    //----------------------------------------------------------
    // 音频接口
    //----------------------------------------------------------
    audio_interface u_audio_interface (
        .clk            (clk),
        .rst_n          (rst_n),
        .mclk           (mclk),
        .sclk           (sclk),
        .fsync          (fsync),
        .sdin1          (sdin1),
        .sdin2          (sdin2),
        .sap_mode       (reg_sap_ctrl[2:0]),
        .audio_data_ch1 (audio_data_ch1),
        .audio_data_ch2 (audio_data_ch2),
        .audio_data_ch3 (audio_data_ch3),
        .audio_data_ch4 (audio_data_ch4),
        .audio_valid    (audio_valid)
    );

    //----------------------------------------------------------
    // PWM生成器
    //----------------------------------------------------------
    pwm_generator u_pwm_generator (
        .clk            (clk),
        .rst_n          (rst_n),
        .audio_data_ch1 (audio_data_ch1),
        .audio_data_ch2 (audio_data_ch2),
        .audio_data_ch3 (audio_data_ch3),
        .audio_data_ch4 (audio_data_ch4),
        .ch1_en         (ch1_en),
        .ch2_en         (ch2_en),
        .ch3_en         (ch3_en),
        .ch4_en         (ch4_en),
        .ch1_mute       (ch1_mute),
        .ch2_mute       (ch2_mute),
        .ch3_mute       (ch3_mute),
        .ch4_mute       (ch4_mute),
        .pwm_freq       (reg_misc_ctrl2[6:4]),
        .out_1p         (out_1p),
        .out_1m         (out_1m),
        .out_2p         (out_2p),
        .out_2m         (out_2m),
        .out_3p         (out_3p),
        .out_3m         (out_3m),
        .out_4p         (out_4p),
        .out_4m         (out_4m)
    );

    //----------------------------------------------------------
    // 诊断控制器
    //----------------------------------------------------------
    diagnostic_ctrl u_diagnostic_ctrl (
        .clk                (clk),
        .rst_n              (rst_n),
        .diag_trigger       (diag_trigger),
        .ch_diag_active     (ch_diag_active),
        .dc_diag_ctrl1      (reg_dc_diag_ctrl1),
        .dc_diag_ctrl2      (reg_dc_diag_ctrl2),
        .dc_diag_ctrl3      (reg_dc_diag_ctrl3),
        .ac_diag_ctrl1      (reg_ac_diag_ctrl1),
        .ac_diag_ctrl2      (reg_ac_diag_ctrl2),
        .dc_diag_rpt1       (hw_dc_diag_rpt1),
        .dc_diag_rpt2       (hw_dc_diag_rpt2),
        .dc_diag_rpt3       (hw_dc_diag_rpt3),
        .ac_diag_rpt_ch1    (hw_ac_diag_rpt_ch1),
        .ac_diag_rpt_ch2    (hw_ac_diag_rpt_ch2),
        .ac_diag_rpt_ch3    (hw_ac_diag_rpt_ch3),
        .ac_diag_rpt_ch4    (hw_ac_diag_rpt_ch4),
        .diag_done          (diag_done)
    );

    //----------------------------------------------------------
    // 故障监控器
    //----------------------------------------------------------
    fault_monitor u_fault_monitor (
        .clk                (clk),
        .rst_n              (rst_n),
        .pad_rst_n          (pad_rst_n),
        .oc_ch1             (oc_ch1),
        .oc_ch2             (oc_ch2),
        .oc_ch3             (oc_ch3),
        .oc_ch4             (oc_ch4),
        .dc_ch1             (dc_ch1),
        .dc_ch2             (dc_ch2),
        .dc_ch3             (dc_ch3),
        .dc_ch4             (dc_ch4),
        .otw                (otw_int),
        .otsd               (otsd_int),
        .vbat_uv            (vbat_uv_int),
        .vbat_ov            (vbat_ov_int),
        .pvdd_uv            (pvdd_uv_int),
        .pvdd_ov            (pvdd_ov_int),
        .clock_lost         (clock_lost),
        .clear_fault        (clear_fault),
        .chip_state         (chip_state),
        .ch_faults          (hw_ch_faults),
        .global_fault1      (hw_global_fault1),
        .global_fault2      (hw_global_fault2),
        .warnings           (hw_warnings),
        .global_fault_irq   (global_fault_irq),
        .ch1_fault          (ch1_fault),
        .ch2_fault          (ch2_fault),
        .ch3_fault          (ch3_fault),
        .ch4_fault          (ch4_fault)
    );

    //----------------------------------------------------------
    // 时钟监控器
    //----------------------------------------------------------
    clock_monitor u_clock_monitor (
        .clk        (clk),
        .rst_n      (rst_n),
        .mclk       (mclk),
        .sclk       (sclk),
        .fsync      (fsync),
        .chip_state (chip_state),
        .clock_lost (clock_lost)
    );

    //----------------------------------------------------------
    // 保护电路
    //----------------------------------------------------------
    protection u_protection (
        .clk                (clk),
        .rst_n              (rst_n),
        .otw_raw            (otw_raw),
        .otsd_raw           (otsd_raw),
        .vbat_uv_raw        (vbat_uv_raw),
        .vbat_ov_raw        (vbat_ov_raw),
        .pvdd_uv_raw        (pvdd_uv_raw),
        .pvdd_ov_raw        (pvdd_ov_raw),
        .otsd_auto_recovery (otsd_auto_recovery),
        .clear_fault        (clear_fault),
        .chip_state         (chip_state),
        .otw                (otw_int),
        .otsd               (otsd_int),
        .vbat_uv            (vbat_uv_int),
        .vbat_ov            (vbat_ov_int),
        .pvdd_uv            (pvdd_uv_int),
        .pvdd_ov            (pvdd_ov_int)
    );

    //----------------------------------------------------------
    // 引脚控制
    //----------------------------------------------------------
    pin_control u_pin_control (
        .clk                (clk),
        .rst_n              (rst_n),
        .standby_n_pin      (standby_n_pin),
        .mute_n_pin         (mute_n_pin),
        .global_fault_irq   (global_fault_irq),
        .any_ch_fault       (any_ch_fault),
        .otw_warning        (otw_warning),
        .por_flag           (por_flag),
        .pin_ctrl_reg       (reg_pin_ctrl),
        .standby_n          (standby_n_int),
        .mute_n             (mute_n_int),
        .fault_n            (fault_n),
        .warn_n             (warn_n)
    );

endmodule
