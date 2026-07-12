/**
 * Module: fault_monitor
 * Description: 故障监控器模块
 *              监控各类故障：过流(OC)、直流检测(DC)、过温警告(OTW)、
 *              过温关断(OTSD)、欠压(UV)、过压(OV)、时钟丢失
 *              故障锁存，CLEAR_FAULT清除
 *              输出故障状态到寄存器文件和主状态机
 *
 * Author: AI Designer
 * Date: 2026-07-11
 * Version: 1.0.0
 *
 * Ports:
 *   - clk: 系统时钟
 *   - rst_n: 异步复位
 *   - oc_ch1~4: 各通道过流输入
 *   - dc_ch1~4: 各通道直流检测输入
 *   - otw: 过温警告输入
 *   - otsd: 过温关断输入
 *   - vbat_uv/pvdd_uv: 欠压输入
 *   - vbat_ov/pvdd_ov: 过压输入
 *   - clock_lost: 时钟丢失输入
 *   - pad_rst_n: POR复位
 *   - clear_fault: 清除故障
 *   - chip_state[2:0]: 芯片状态
 *   - ch_faults[7:0]: 通道故障输出(0x10)
 *   - global_fault1[7:0]: 全局故障1输出(0x11)
 *   - global_fault2[7:0]: 全局故障2输出(0x12)
 *   - warnings[7:0]: 警告输出(0x13)
 *   - global_fault_irq: 全局故障中断信号(到主状态机)
 *   - ch1~4_fault: 各通道故障信号(到通道状态机)
 */

`timescale 1ns/1ps

`include "tas6424e_defines.v"

module fault_monitor (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        pad_rst_n,

    // 故障输入（来自模拟前端/保护电路）
    input  wire        oc_ch1,             // 通道1过流
    input  wire        oc_ch2,             // 通道2过流
    input  wire        oc_ch3,             // 通道3过流
    input  wire        oc_ch4,             // 通道4过流
    input  wire        dc_ch1,             // 通道1直流检测
    input  wire        dc_ch2,             // 通道2直流检测
    input  wire        dc_ch3,             // 通道3直流检测
    input  wire        dc_ch4,             // 通道4直流检测
    input  wire        otw,                // 过温警告
    input  wire        otsd,               // 过温关断
    input  wire        vbat_uv,            // VBAT欠压
    input  wire        vbat_ov,            // VBAT过压
    input  wire        pvdd_uv,            // PVDD欠压
    input  wire        pvdd_ov,            // PVDD过压
    input  wire        clock_lost,         // 时钟丢失
    input  wire        clear_fault,        // 清除故障
    input  wire [2:0]  chip_state,         // 芯片状态

    // 故障输出到寄存器
    output reg  [7:0]  ch_faults,          // 0x10: CH1-4 OC[7:4], CH1-4 DC[3:0]
    output reg  [7:0]  global_fault1,      // 0x11: CLK, PVDD_OV, VBAT_OV, PVDD_UV, VBAT_UV
    output reg  [7:0]  global_fault2,      // 0x12: OTSD, CH1-4 OTSD
    output reg  [7:0]  warnings,           // 0x13: POR, OTW, CH1-4 OTW

    // 故障中断到状态机
    output wire        global_fault_irq,   // 全局故障中断
    output wire        ch1_fault,          // 通道1故障
    output wire        ch2_fault,          // 通道2故障
    output wire        ch3_fault,          // 通道3故障
    output wire        ch4_fault           // 通道4故障
);

    //----------------------------------------------------------
    // 内部复位
    //----------------------------------------------------------
    wire internal_rst_n = rst_n & pad_rst_n;

    //----------------------------------------------------------
    // 故障去毛刺（仿真简化：直接使用输入）
    // 实际芯片需要去毛刺滤波器
    //----------------------------------------------------------

    //----------------------------------------------------------
    // 通道故障锁存寄存器
    // OC和DC故障都锁存，直到CLEAR_FAULT
    //----------------------------------------------------------
    reg ch1_oc_reg, ch1_dc_reg;
    reg ch2_oc_reg, ch2_dc_reg;
    reg ch3_oc_reg, ch3_dc_reg;
    reg ch4_oc_reg, ch4_dc_reg;

    // 全局故障锁存寄存器
    reg vbat_uv_reg, vbat_ov_reg;
    reg pvdd_uv_reg, pvdd_ov_reg;
    reg clock_invalid_reg;
    reg otsd_reg;

    // 警告寄存器（不锁存，实时反映）
    reg otw_reg;
    reg por_reg;

    //----------------------------------------------------------
    // 通道故障锁存（时序逻辑）
    //----------------------------------------------------------
    always @(posedge clk or negedge internal_rst_n) begin
        if (!internal_rst_n) begin
            ch1_oc_reg <= 1'b0; ch1_dc_reg <= 1'b0;
            ch2_oc_reg <= 1'b0; ch2_dc_reg <= 1'b0;
            ch3_oc_reg <= 1'b0; ch3_dc_reg <= 1'b0;
            ch4_oc_reg <= 1'b0; ch4_dc_reg <= 1'b0;
        end else begin
            if (clear_fault) begin
                ch1_oc_reg <= 1'b0; ch1_dc_reg <= 1'b0;
                ch2_oc_reg <= 1'b0; ch2_dc_reg <= 1'b0;
                ch3_oc_reg <= 1'b0; ch3_dc_reg <= 1'b0;
                ch4_oc_reg <= 1'b0; ch4_dc_reg <= 1'b0;
            end else begin
                // 故障仅在Hi-Z/MUTE/PLAY态有效
                if (chip_state == `CHIP_HI_Z ||
                    chip_state == `CHIP_MUTE ||
                    chip_state == `CHIP_PLAY) begin
                    if (oc_ch1) ch1_oc_reg <= 1'b1;
                    if (oc_ch2) ch2_oc_reg <= 1'b1;
                    if (oc_ch3) ch3_oc_reg <= 1'b1;
                    if (oc_ch4) ch4_oc_reg <= 1'b1;
                    if (dc_ch1) ch1_dc_reg <= 1'b1;
                    if (dc_ch2) ch2_dc_reg <= 1'b1;
                    if (dc_ch3) ch3_dc_reg <= 1'b1;
                    if (dc_ch4) ch4_dc_reg <= 1'b1;
                end
            end
        end
    end

    //----------------------------------------------------------
    // 全局故障锁存（时序逻辑）
    //----------------------------------------------------------
    always @(posedge clk or negedge internal_rst_n) begin
        if (!internal_rst_n) begin
            vbat_uv_reg    <= 1'b0;
            vbat_ov_reg    <= 1'b0;
            pvdd_uv_reg    <= 1'b0;
            pvdd_ov_reg    <= 1'b0;
            clock_invalid_reg <= 1'b0;
            otsd_reg       <= 1'b0;
        end else begin
            if (clear_fault) begin
                vbat_uv_reg    <= 1'b0;
                vbat_ov_reg    <= 1'b0;
                pvdd_uv_reg    <= 1'b0;
                pvdd_ov_reg    <= 1'b0;
                clock_invalid_reg <= 1'b0;
                otsd_reg       <= 1'b0;
            end else begin
                // 电压/时钟故障在Hi-Z/MUTE/PLAY态有效
                if (chip_state == `CHIP_HI_Z ||
                    chip_state == `CHIP_MUTE ||
                    chip_state == `CHIP_PLAY) begin
                    if (vbat_uv) vbat_uv_reg <= 1'b1;
                    if (vbat_ov) vbat_ov_reg <= 1'b1;
                    if (pvdd_uv) pvdd_uv_reg <= 1'b1;
                    if (pvdd_ov) pvdd_ov_reg <= 1'b1;
                    if (clock_lost) clock_invalid_reg <= 1'b1;
                    if (otsd) otsd_reg <= 1'b1;
                end
            end
        end
    end

    //----------------------------------------------------------
    // POR和OTW标志（时序逻辑）
    // POR锁存直到CLEAR_FAULT，OTW实时反映
    //----------------------------------------------------------
    always @(posedge clk or negedge internal_rst_n) begin
        if (!internal_rst_n) begin
            por_reg <= 1'b1;       // POR上电默认置位
            otw_reg <= 1'b0;
        end else begin
            if (clear_fault) begin
                por_reg <= 1'b0;   // CLEAR_FAULT清除POR标志
            end
            otw_reg <= otw;        // OTW实时反映
        end
    end

    //----------------------------------------------------------
    // 故障寄存器输出组装
    //----------------------------------------------------------
    // 0x10 Channel Faults: OC[7:4]=CH4~CH1, DC[3:0]=CH4~CH1
    always @(*) begin
        ch_faults = {ch4_oc_reg, ch3_oc_reg, ch2_oc_reg, ch1_oc_reg,
                     ch4_dc_reg, ch3_dc_reg, ch2_dc_reg, ch1_dc_reg};
    end

    // 0x11 Global Faults 1: bit4=INVALID_CLOCK, bit3=PVDD_OV,
    //                      bit2=VBAT_OV, bit1=PVDD_UV, bit0=VBAT_UV
    always @(*) begin
        global_fault1 = {4'b0000, clock_invalid_reg, pvdd_ov_reg,
                         vbat_ov_reg, pvdd_uv_reg, vbat_uv_reg};
    end

    // 0x12 Global Faults 2: bit4=OTSD
    always @(*) begin
        global_fault2 = {4'b0000, otsd_reg, 3'b000};
    end

    // 0x13 Warnings: bit5=POR, bit4=OTW
    always @(*) begin
        warnings = {2'b00, por_reg, otw_reg, 4'b0000};
    end

    //----------------------------------------------------------
    // 故障中断信号生成（组合逻辑）
    //----------------------------------------------------------
    // 全局故障：UV/OV/OTSD/时钟错误 → 强制进入Hi-Z
    assign global_fault_irq = vbat_uv_reg | vbat_ov_reg |
                              pvdd_uv_reg | pvdd_ov_reg |
                              otsd_reg | clock_invalid_reg;

    // 通道故障：OC或DC → 对应通道进入Hi-Z
    assign ch1_fault = ch1_oc_reg | ch1_dc_reg;
    assign ch2_fault = ch2_oc_reg | ch2_dc_reg;
    assign ch3_fault = ch3_oc_reg | ch3_dc_reg;
    assign ch4_fault = ch4_oc_reg | ch4_dc_reg;

endmodule
