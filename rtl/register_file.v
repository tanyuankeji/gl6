/**
 * Module: register_file
 * Description: 寄存器文件模块
 *              实现0x00-0x79地址空间的寄存器存储
 *              支持I2C读写接口和内部硬件读写接口
 *              R/W类型寄存器由I2C驱动，R类型寄存器由内部硬件驱动
 *              上电默认值按datasheet精确配置
 *
 * Author: AI Designer
 * Date: 2026-07-11
 * Version: 1.0.0
 *
 * Ports:
 *   - clk: 系统时钟
 *   - rst_n: 异步复位
 *   - pad_rst_n: POR复位（触发所有寄存器恢复默认值）
 *   - i2c_wr_en/i2c_wr_addr/i2c_wr_data: I2C写接口
 *   - i2c_rd_en/i2c_rd_addr/i2c_rd_data: I2C读接口
 *   - 各寄存器输出到内部模块
 *   - 硬件写入接口（故障/诊断/状态报告寄存器）
 *   - soft_reset: 软件复位信号（0x00 bit7）
 *   - clear_fault: 故障清除信号（0x21 bit7）
 */

`timescale 1ns/1ps

`include "tas6424e_defines.v"

module register_file (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        pad_rst_n,           // POR复位

    // I2C写接口
    input  wire        i2c_wr_en,
    input  wire [7:0]  i2c_wr_addr,
    input  wire [7:0]  i2c_wr_data,

    // I2C读接口
    input  wire        i2c_rd_en,
    input  wire [7:0]  i2c_rd_addr,
    output reg  [7:0]  i2c_rd_data,

    // 配置寄存器输出（R/W类型，由I2C配置）
    output wire [7:0]  reg_mode_ctrl,       // 0x00
    output wire [7:0]  reg_misc_ctrl1,      // 0x01
    output wire [7:0]  reg_misc_ctrl2,      // 0x02
    output wire [7:0]  reg_sap_ctrl,        // 0x03
    output wire [7:0]  reg_ch_state_ctrl,   // 0x04
    output wire [7:0]  reg_ch1_vol,         // 0x05
    output wire [7:0]  reg_ch2_vol,         // 0x06
    output wire [7:0]  reg_ch3_vol,         // 0x07
    output wire [7:0]  reg_ch4_vol,         // 0x08
    output wire [7:0]  reg_dc_diag_ctrl1,   // 0x09
    output wire [7:0]  reg_dc_diag_ctrl2,   // 0x0A
    output wire [7:0]  reg_dc_diag_ctrl3,   // 0x0B
    output wire [7:0]  reg_pin_ctrl,        // 0x14
    output wire [7:0]  reg_ac_diag_ctrl1,   // 0x15
    output wire [7:0]  reg_ac_diag_ctrl2,   // 0x16
    output wire [7:0]  reg_misc_ctrl3,      // 0x21
    output wire [7:0]  reg_clip_ctrl,       // 0x22
    output wire [7:0]  reg_clip_window,     // 0x23
    output wire [7:0]  reg_misc_ctrl4,      // 0x26
    output wire [7:0]  reg_misc_ctrl5,      // 0x28
    output wire [7:0]  reg_ss_ctrl1,        // 0x77
    output wire [7:0]  reg_ss_ctrl2,        // 0x78
    output wire [7:0]  reg_ss_ctrl3,        // 0x79

    // 硬件写入接口（R类型寄存器，由内部模块驱动）
    input  wire [7:0]  hw_dc_diag_rpt1,     // 0x0C
    input  wire [7:0]  hw_dc_diag_rpt2,     // 0x0D
    input  wire [7:0]  hw_dc_diag_rpt3,     // 0x0E
    input  wire [7:0]  hw_ch_state_rpt,     // 0x0F
    input  wire [7:0]  hw_ch_faults,        // 0x10
    input  wire [7:0]  hw_global_fault1,    // 0x11
    input  wire [7:0]  hw_global_fault2,    // 0x12
    input  wire [7:0]  hw_warnings,         // 0x13
    input  wire [7:0]  hw_ac_diag_rpt_ch1,  // 0x17
    input  wire [7:0]  hw_ac_diag_rpt_ch2,  // 0x18
    input  wire [7:0]  hw_ac_diag_rpt_ch3,  // 0x19
    input  wire [7:0]  hw_ac_diag_rpt_ch4,  // 0x1A
    input  wire [7:0]  hw_clip_warning,     // 0x24
    input  wire [7:0]  hw_ilimit_status,    // 0x25

    // 特殊控制信号输出
    output wire        soft_reset,          // 0x00 bit7 软件复位
    output wire        clear_fault,         // 0x21 bit7 清除故障
    output wire        otsd_auto_recovery   // 0x21 bit3 过温自动恢复
);

    //----------------------------------------------------------
    // R/W类型寄存器存储
    // 这些寄存器由I2C写入，上电时加载默认值
    //----------------------------------------------------------
    reg [7:0] mode_ctrl_reg;
    reg [7:0] misc_ctrl1_reg;
    reg [7:0] misc_ctrl2_reg;
    reg [7:0] sap_ctrl_reg;
    reg [7:0] ch_state_ctrl_reg;
    reg [7:0] ch1_vol_reg;
    reg [7:0] ch2_vol_reg;
    reg [7:0] ch3_vol_reg;
    reg [7:0] ch4_vol_reg;
    reg [7:0] dc_diag_ctrl1_reg;
    reg [7:0] dc_diag_ctrl2_reg;
    reg [7:0] dc_diag_ctrl3_reg;
    reg [7:0] pin_ctrl_reg;
    reg [7:0] ac_diag_ctrl1_reg;
    reg [7:0] ac_diag_ctrl2_reg;
    reg [7:0] misc_ctrl3_reg;
    reg [7:0] clip_ctrl_reg;
    reg [7:0] clip_window_reg;
    reg [7:0] misc_ctrl4_reg;
    reg [7:0] misc_ctrl5_reg;
    reg [7:0] ss_ctrl1_reg;
    reg [7:0] ss_ctrl2_reg;
    reg [7:0] ss_ctrl3_reg;

    //----------------------------------------------------------
    // 内部复位信号：异步复位或POR或软件复位
    //----------------------------------------------------------
    wire internal_rst_n = rst_n & pad_rst_n;

    //----------------------------------------------------------
    // R/W寄存器写逻辑
    // I2C写使能时根据地址写入对应寄存器
    // soft_reset写入时触发复位脉冲（自清除）
    //----------------------------------------------------------
    always @(posedge clk or negedge internal_rst_n) begin
        if (!internal_rst_n) begin
            // 上电/POR/软件复位时恢复默认值
            mode_ctrl_reg      <= `DEF_MODE_CTRL;
            misc_ctrl1_reg     <= `DEF_MISC_CTRL1;
            misc_ctrl2_reg     <= `DEF_MISC_CTRL2;
            sap_ctrl_reg       <= `DEF_SAP_CTRL;
            ch_state_ctrl_reg  <= `DEF_CH_STATE_CTRL;
            ch1_vol_reg        <= `DEF_CH_VOL;
            ch2_vol_reg        <= `DEF_CH_VOL;
            ch3_vol_reg        <= `DEF_CH_VOL;
            ch4_vol_reg        <= `DEF_CH_VOL;
            dc_diag_ctrl1_reg  <= 8'h00;
            dc_diag_ctrl2_reg  <= 8'h00;
            dc_diag_ctrl3_reg  <= 8'h00;
            pin_ctrl_reg       <= `DEF_PIN_CTRL;
            ac_diag_ctrl1_reg  <= 8'h00;
            ac_diag_ctrl2_reg  <= 8'h00;
            misc_ctrl3_reg     <= `DEF_MISC_CTRL3;
            clip_ctrl_reg      <= `DEF_CLIP_CTRL;
            clip_window_reg    <= `DEF_CLIP_WINDOW;
            misc_ctrl4_reg     <= `DEF_MISC_CTRL4;
            misc_ctrl5_reg     <= `DEF_MISC_CTRL5;
            ss_ctrl1_reg       <= 8'h00;
            ss_ctrl2_reg       <= 8'h00;
            ss_ctrl3_reg       <= 8'h00;
        end else begin
            if (i2c_wr_en) begin
                case (i2c_wr_addr)
                    `REG_MODE_CTRL:     mode_ctrl_reg     <= i2c_wr_data;
                    `REG_MISC_CTRL1:    misc_ctrl1_reg    <= i2c_wr_data;
                    `REG_MISC_CTRL2:    misc_ctrl2_reg    <= i2c_wr_data;
                    `REG_SAP_CTRL:      sap_ctrl_reg      <= i2c_wr_data;
                    `REG_CH_STATE_CTRL: ch_state_ctrl_reg <= i2c_wr_data;
                    `REG_CH1_VOL:       ch1_vol_reg       <= i2c_wr_data;
                    `REG_CH2_VOL:       ch2_vol_reg       <= i2c_wr_data;
                    `REG_CH3_VOL:       ch3_vol_reg       <= i2c_wr_data;
                    `REG_CH4_VOL:       ch4_vol_reg       <= i2c_wr_data;
                    `REG_DC_DIAG_CTRL1: dc_diag_ctrl1_reg <= i2c_wr_data;
                    `REG_DC_DIAG_CTRL2: dc_diag_ctrl2_reg <= i2c_wr_data;
                    `REG_DC_DIAG_CTRL3: dc_diag_ctrl3_reg <= i2c_wr_data;
                    `REG_PIN_CTRL:      pin_ctrl_reg      <= i2c_wr_data;
                    `REG_AC_DIAG_CTRL1: ac_diag_ctrl1_reg <= i2c_wr_data;
                    `REG_AC_DIAG_CTRL2: ac_diag_ctrl2_reg <= i2c_wr_data;
                    `REG_MISC_CTRL3:    misc_ctrl3_reg    <= i2c_wr_data;
                    `REG_CLIP_CTRL:     clip_ctrl_reg     <= i2c_wr_data;
                    `REG_CLIP_WINDOW:   clip_window_reg   <= i2c_wr_data;
                    `REG_MISC_CTRL4:    misc_ctrl4_reg    <= i2c_wr_data;
                    `REG_MISC_CTRL5:    misc_ctrl5_reg    <= i2c_wr_data;
                    `REG_SS_CTRL1:      ss_ctrl1_reg      <= i2c_wr_data;
                    `REG_SS_CTRL2:      ss_ctrl2_reg      <= i2c_wr_data;
                    `REG_SS_CTRL3:      ss_ctrl3_reg      <= i2c_wr_data;
                    default: ; // 未定义地址，忽略
                endcase
            end
            // soft_reset是自清除的：写入后立即清除
            if (mode_ctrl_reg[`MODE_RESET_BIT] && !i2c_wr_en) begin
                mode_ctrl_reg[`MODE_RESET_BIT] <= 1'b0;
            end
        end
    end

    //----------------------------------------------------------
    // I2C读逻辑
    // 根据读地址返回对应寄存器的值
    // R类型寄存器返回硬件写入的值，R/W类型返回存储值
    //----------------------------------------------------------
    always @(*) begin
        case (i2c_rd_addr)
            `REG_MODE_CTRL:         i2c_rd_data = mode_ctrl_reg;
            `REG_MISC_CTRL1:        i2c_rd_data = misc_ctrl1_reg;
            `REG_MISC_CTRL2:        i2c_rd_data = misc_ctrl2_reg;
            `REG_SAP_CTRL:          i2c_rd_data = sap_ctrl_reg;
            `REG_CH_STATE_CTRL:     i2c_rd_data = ch_state_ctrl_reg;
            `REG_CH1_VOL:           i2c_rd_data = ch1_vol_reg;
            `REG_CH2_VOL:           i2c_rd_data = ch2_vol_reg;
            `REG_CH3_VOL:           i2c_rd_data = ch3_vol_reg;
            `REG_CH4_VOL:           i2c_rd_data = ch4_vol_reg;
            `REG_DC_DIAG_CTRL1:     i2c_rd_data = dc_diag_ctrl1_reg;
            `REG_DC_DIAG_CTRL2:     i2c_rd_data = dc_diag_ctrl2_reg;
            `REG_DC_DIAG_CTRL3:     i2c_rd_data = dc_diag_ctrl3_reg;
            // R类型：硬件写入的寄存器
            `REG_DC_DIAG_RPT1:      i2c_rd_data = hw_dc_diag_rpt1;
            `REG_DC_DIAG_RPT2:      i2c_rd_data = hw_dc_diag_rpt2;
            `REG_DC_DIAG_RPT3:      i2c_rd_data = hw_dc_diag_rpt3;
            `REG_CH_STATE_RPT:      i2c_rd_data = hw_ch_state_rpt;
            `REG_CH_FAULTS:         i2c_rd_data = hw_ch_faults;
            `REG_GLOBAL_FAULT1:     i2c_rd_data = hw_global_fault1;
            `REG_GLOBAL_FAULT2:     i2c_rd_data = hw_global_fault2;
            `REG_WARNINGS:          i2c_rd_data = hw_warnings;
            `REG_PIN_CTRL:          i2c_rd_data = pin_ctrl_reg;
            `REG_AC_DIAG_CTRL1:     i2c_rd_data = ac_diag_ctrl1_reg;
            `REG_AC_DIAG_CTRL2:     i2c_rd_data = ac_diag_ctrl2_reg;
            `REG_AC_DIAG_RPT_CH1:   i2c_rd_data = hw_ac_diag_rpt_ch1;
            `REG_AC_DIAG_RPT_CH2:   i2c_rd_data = hw_ac_diag_rpt_ch2;
            `REG_AC_DIAG_RPT_CH3:   i2c_rd_data = hw_ac_diag_rpt_ch3;
            `REG_AC_DIAG_RPT_CH4:   i2c_rd_data = hw_ac_diag_rpt_ch4;
            `REG_MISC_CTRL3:        i2c_rd_data = misc_ctrl3_reg;
            `REG_CLIP_CTRL:         i2c_rd_data = clip_ctrl_reg;
            `REG_CLIP_WINDOW:       i2c_rd_data = clip_window_reg;
            `REG_CLIP_WARNING:      i2c_rd_data = hw_clip_warning;
            `REG_ILIMIT_STATUS:     i2c_rd_data = hw_ilimit_status;
            `REG_MISC_CTRL4:        i2c_rd_data = misc_ctrl4_reg;
            `REG_MISC_CTRL5:        i2c_rd_data = misc_ctrl5_reg;
            `REG_SS_CTRL1:          i2c_rd_data = ss_ctrl1_reg;
            `REG_SS_CTRL2:          i2c_rd_data = ss_ctrl2_reg;
            `REG_SS_CTRL3:          i2c_rd_data = ss_ctrl3_reg;
            default:                i2c_rd_data = 8'h00;   // 未定义地址返回0
        endcase
    end

    //----------------------------------------------------------
    // 寄存器输出赋值
    //----------------------------------------------------------
    assign reg_mode_ctrl      = mode_ctrl_reg;
    assign reg_misc_ctrl1     = misc_ctrl1_reg;
    assign reg_misc_ctrl2     = misc_ctrl2_reg;
    assign reg_sap_ctrl       = sap_ctrl_reg;
    assign reg_ch_state_ctrl  = ch_state_ctrl_reg;
    assign reg_ch1_vol        = ch1_vol_reg;
    assign reg_ch2_vol        = ch2_vol_reg;
    assign reg_ch3_vol        = ch3_vol_reg;
    assign reg_ch4_vol        = ch4_vol_reg;
    assign reg_dc_diag_ctrl1  = dc_diag_ctrl1_reg;
    assign reg_dc_diag_ctrl2  = dc_diag_ctrl2_reg;
    assign reg_dc_diag_ctrl3  = dc_diag_ctrl3_reg;
    assign reg_pin_ctrl       = pin_ctrl_reg;
    assign reg_ac_diag_ctrl1  = ac_diag_ctrl1_reg;
    assign reg_ac_diag_ctrl2  = ac_diag_ctrl2_reg;
    assign reg_misc_ctrl3     = misc_ctrl3_reg;
    assign reg_clip_ctrl      = clip_ctrl_reg;
    assign reg_clip_window    = clip_window_reg;
    assign reg_misc_ctrl4     = misc_ctrl4_reg;
    assign reg_misc_ctrl5     = misc_ctrl5_reg;
    assign reg_ss_ctrl1       = ss_ctrl1_reg;
    assign reg_ss_ctrl2       = ss_ctrl2_reg;
    assign reg_ss_ctrl3       = ss_ctrl3_reg;

    //----------------------------------------------------------
    // 特殊控制信号输出
    //----------------------------------------------------------
    assign soft_reset         = mode_ctrl_reg[`MODE_RESET_BIT];
    assign clear_fault        = misc_ctrl3_reg[`MISC3_CLEAR_FAULT_BIT];
    assign otsd_auto_recovery = misc_ctrl3_reg[`MISC3_OTSD_AUTO_RCV_BIT];

endmodule
