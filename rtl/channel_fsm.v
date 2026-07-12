/**
 * Module: channel_fsm
 * Description: 通道状态机模块（4个实例，每通道独立）
 *              管理每通道的PLAY/Hi-Z/MUTE/DC_DIAG状态
 *              主状态机全局状态与0x04寄存器配置协调
 *              通道故障时该通道进入Hi-Z，其他通道不受影响
 *
 * Author: AI Designer
 * Date: 2026-07-11
 * Version: 1.0.0
 *
 * Ports:
 *   - clk: 系统时钟
 *   - rst_n: 异步复位
 *   - chip_state[2:0]: 主状态机全局状态
 *   - ch_state_req[1:0]: 该通道的0x04寄存器配置
 *   - ch_fault: 该通道故障信号（OC/DC故障）
 *   - clear_fault: 清除故障信号
 *   - diag_trigger: 诊断触发
 *   - diag_done: 诊断完成
 *   - ch_state[1:0]: 该通道当前状态
 *   - ch_en: 通道使能（1=FETs开关，0=FETs高阻）
 *   - ch_mute_mode: 通道静音模式（1=50%占空比）
 *   - ch_diag_active: 通道诊断进行中
 */

`timescale 1ns/1ps

`include "tas6424e_defines.v"

module channel_fsm (
    input  wire        clk,
    input  wire        rst_n,

    // 控制输入
    input  wire [2:0]  chip_state,        // 主状态机全局状态
    input  wire [1:0]  ch_state_req,      // 0x04该通道配置
    input  wire        ch_fault,          // 该通道故障
    input  wire        clear_fault,       // 清除故障
    input  wire        diag_trigger,      // 诊断触发
    input  wire        diag_done,         // 诊断完成

    // 状态输出
    output reg  [1:0]  ch_state,          // 当前通道状态
    output wire        ch_en,             // 通道使能（PWM输出允许）
    output wire        ch_mute_mode,      // 静音模式标志
    output wire        ch_diag_active     // 诊断进行中标志
);

    //----------------------------------------------------------
    // 通道故障锁存
    // 通道故障发生时锁存，CLEAR_FAULT清除
    //----------------------------------------------------------
    reg ch_fault_latched_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ch_fault_latched_reg <= 1'b0;
        end else begin
            if (clear_fault) begin
                ch_fault_latched_reg <= 1'b0;       // 清除故障锁存
            end else if (ch_fault) begin
                ch_fault_latched_reg <= 1'b1;       // 锁存通道故障
            end
        end
    end

    //----------------------------------------------------------
    // 通道状态寄存器（时序逻辑）
    // 根据0x04配置和故障状态决定通道状态
    //----------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ch_state <= `CH_HI_Z;           // 复位到Hi-Z
        end else begin
            // 通道故障锁存：强制进入Hi-Z
            if (ch_fault_latched_reg) begin
                ch_state <= `CH_HI_Z;
            // 主状态机不在PLAY/MUTE/DIAG时：通道必须Hi-Z
            end else if (chip_state == `CHIP_STANDBY ||
                         chip_state == `CHIP_HI_Z) begin
                ch_state <= `CH_HI_Z;
            // 主状态机在DIAG态：通道按0x04诊断配置
            end else if (chip_state == `CHIP_DIAG) begin
                if (ch_state_req == `CH_DC_DIAG) begin
                    ch_state <= `CH_DC_DIAG;
                end else begin
                    ch_state <= `CH_HI_Z;   // 非诊断通道保持Hi-Z
                end
            // 主状态机在PLAY/MUTE态：通道按0x04配置
            end else begin
                ch_state <= ch_state_req;
            end
        end
    end

    //----------------------------------------------------------
    // 通道输出信号生成（组合逻辑）
    //----------------------------------------------------------
    // 通道使能：仅在PLAY和MUTE态FETs开关
    assign ch_en = (ch_state == `CH_PLAY) || (ch_state == `CH_MUTE);

    // 静音模式：MUTE态时50%占空比
    assign ch_mute_mode = (ch_state == `CH_MUTE);

    // 诊断进行中
    assign ch_diag_active = (ch_state == `CH_DC_DIAG);

endmodule
