/**
 * Module: state_machine
 * Description: 芯片主状态机模块
 *              管理芯片全局状态转换：STANDBY → HI_Z → MUTE → PLAY → DIAG
 *              处理正常工作流程和故障恢复流程
 *              两段式FSM：状态寄存器 + 组合逻辑下一状态
 *
 * Author: AI Designer
 * Date: 2026-07-11
 * Version: 1.0.0
 *
 * Ports:
 *   - clk: 系统时钟
 *   - rst_n: 异步复位
 *   - standby_n: STANDBY引脚输入（去抖动后）
 *   - ch_state_ctrl[7:0]: 0x04寄存器值（通道状态控制）
 *   - global_fault: 全局故障发生信号（POR/UV/OV/OTSD等）
 *   - diag_done: DC诊断完成信号
 *   - chip_state[2:0]: 当前芯片状态输出
 *   - diag_trigger: 诊断触发信号（进入DIAG态时脉冲）
 */

`timescale 1ns/1ps

`include "tas6424e_defines.v"

module state_machine (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        pad_rst_n,          // POR复位

    // 控制输入
    input  wire        standby_n,          // STANDBY引脚（去抖动后）
    input  wire [7:0]  ch_state_ctrl,      // 0x04通道状态控制寄存器
    input  wire        global_fault,       // 全局故障信号
    input  wire        diag_done,          // 诊断完成信号
    input  wire        clear_fault,        // 清除故障信号

    // 状态输出
    output reg  [2:0]  chip_state,         // 当前芯片状态
    output reg         diag_trigger        // 诊断触发脉冲
);

    //----------------------------------------------------------
    // 内部复位
    //----------------------------------------------------------
    wire internal_rst_n = rst_n & pad_rst_n;

    //----------------------------------------------------------
    // 从0x04寄存器提取各通道状态
    // 判断是否有通道请求DC诊断
    //----------------------------------------------------------
    wire any_ch_diag = (ch_state_ctrl[1:0]   == `CH_DC_DIAG) ||
                       (ch_state_ctrl[3:2]   == `CH_DC_DIAG) ||
                       (ch_state_ctrl[5:4]   == `CH_DC_DIAG) ||
                       (ch_state_ctrl[7:6]   == `CH_DC_DIAG);

    // 判断是否有通道请求播放或静音
    wire any_ch_play = (ch_state_ctrl[1:0]   == `CH_PLAY) ||
                       (ch_state_ctrl[3:2]   == `CH_PLAY) ||
                       (ch_state_ctrl[5:4]   == `CH_PLAY) ||
                       (ch_state_ctrl[7:6]   == `CH_PLAY);

    wire any_ch_mute = (ch_state_ctrl[1:0]   == `CH_MUTE) ||
                       (ch_state_ctrl[3:2]   == `CH_MUTE) ||
                       (ch_state_ctrl[5:4]   == `CH_MUTE) ||
                       (ch_state_ctrl[7:6]   == `CH_MUTE);

    // 判断是否所有通道都是Hi-Z
    wire all_ch_hiz  = (ch_state_ctrl[1:0]   == `CH_HI_Z) &&
                       (ch_state_ctrl[3:2]   == `CH_HI_Z) &&
                       (ch_state_ctrl[5:4]   == `CH_HI_Z) &&
                       (ch_state_ctrl[7:6]   == `CH_HI_Z);

    //----------------------------------------------------------
    // 下一状态组合逻辑
    //----------------------------------------------------------
    reg [2:0] state_next;

    always @(*) begin
        // 默认保持当前状态
        state_next = chip_state;

        case (chip_state)
            `CHIP_STANDBY: begin
                // STANDBY + standby_n=1 → HI_Z
                if (standby_n) begin
                    state_next = `CHIP_HI_Z;
                end
            end

            `CHIP_HI_Z: begin
                // HI_Z + 全局故障 → 保持HI_Z（故障处理在此态）
                if (global_fault) begin
                    state_next = `CHIP_HI_Z;
                // HI_Z + standby_n=0 → STANDBY
                end else if (!standby_n) begin
                    state_next = `CHIP_STANDBY;
                // HI_Z + 有通道请求诊断 → DIAG
                end else if (any_ch_diag) begin
                    state_next = `CHIP_DIAG;
                // HI_Z + 有通道请求播放 → PLAY
                end else if (any_ch_play) begin
                    state_next = `CHIP_PLAY;
                // HI_Z + 有通道请求静音 → MUTE
                end else if (any_ch_mute) begin
                    state_next = `CHIP_MUTE;
                end
            end

            `CHIP_MUTE: begin
                // MUTE + 全局故障 → HI_Z
                if (global_fault) begin
                    state_next = `CHIP_HI_Z;
                // MUTE + standby_n=0 → STANDBY
                end else if (!standby_n) begin
                    state_next = `CHIP_STANDBY;
                // MUTE + 有通道请求诊断 → DIAG
                end else if (any_ch_diag) begin
                    state_next = `CHIP_DIAG;
                // MUTE + 无静音请求且有播放请求 → PLAY
                end else if (any_ch_play && !any_ch_mute) begin
                    state_next = `CHIP_PLAY;
                // MUTE + 所有通道Hi-Z → HI_Z
                end else if (all_ch_hiz) begin
                    state_next = `CHIP_HI_Z;
                end
            end

            `CHIP_PLAY: begin
                // PLAY + 全局故障 → HI_Z
                if (global_fault) begin
                    state_next = `CHIP_HI_Z;
                // PLAY + standby_n=0 → STANDBY
                end else if (!standby_n) begin
                    state_next = `CHIP_STANDBY;
                // PLAY + 有通道请求诊断 → DIAG
                end else if (any_ch_diag) begin
                    state_next = `CHIP_DIAG;
                // PLAY + 无播放请求且有静音请求 → MUTE
                end else if (any_ch_mute && !any_ch_play) begin
                    state_next = `CHIP_MUTE;
                // PLAY + 所有通道Hi-Z → HI_Z
                end else if (all_ch_hiz) begin
                    state_next = `CHIP_HI_Z;
                end
            end

            `CHIP_DIAG: begin
                // DIAG + 全局故障 → HI_Z
                if (global_fault) begin
                    state_next = `CHIP_HI_Z;
                // DIAG + 诊断完成 → HI_Z
                end else if (diag_done) begin
                    state_next = `CHIP_HI_Z;
                // DIAG + standby_n=0 → STANDBY
                end else if (!standby_n) begin
                    state_next = `CHIP_STANDBY;
                end
            end

            default: state_next = `CHIP_STANDBY;
        endcase
    end

    //----------------------------------------------------------
    // 状态寄存器（时序逻辑）
    //----------------------------------------------------------
    always @(posedge clk or negedge internal_rst_n) begin
        if (!internal_rst_n) begin
            chip_state <= `CHIP_STANDBY;
        end else begin
            chip_state <= state_next;
        end
    end

    //----------------------------------------------------------
    // 诊断触发脉冲生成
    // 进入DIAG态时产生一个周期脉冲
    //----------------------------------------------------------
    always @(posedge clk or negedge internal_rst_n) begin
        if (!internal_rst_n) begin
            diag_trigger <= 1'b0;
        end else begin
            if (chip_state != `CHIP_DIAG && state_next == `CHIP_DIAG) begin
                diag_trigger <= 1'b1;
            end else begin
                diag_trigger <= 1'b0;
            end
        end
    end

endmodule
