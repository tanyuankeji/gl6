// ============================================================================
// TAS6424E-Q1 全局参数定义
// 统一所有模块共享的常量、编码、时序参数
// ============================================================================

`ifndef TAS6424E_DEFINES_VH
`define TAS6424E_DEFINES_VH

// ========================================================================
// 芯片顶层状态机编码
// ========================================================================
parameter CHIP_POWERON = 2'd0;
parameter CHIP_STANDBY = 2'd1;
parameter CHIP_ACT     = 2'd2;

// ========================================================================
// 通道状态机编码 (6态, 3bit)
// ========================================================================
parameter CH_IDLE          = 3'd0;   // 上电初始
parameter CH_HIGH_Z        = 3'd1;   // 高阻/默认 (0x04=01)
parameter CH_PLAY          = 3'd2;   // 播放   (0x04=00)
parameter CH_MUTE          = 3'd3;   // 静音   (0x04=10 / hw_mute_n=0)
parameter CH_DC_DIAG_ENTRY = 3'd4;   // DC诊断桥接 (0x04=11)
parameter CH_AC_DIAG_ENTRY = 3'd5;   // AC诊断桥接 (0x15/0x16)

// ========================================================================
// 0x04寄存器通道状态请求编码
// ========================================================================
parameter CH_REQ_PLAY  = 2'b00;
parameter CH_REQ_HI_Z  = 2'b01;
parameter CH_REQ_MUTE  = 2'b10;
parameter CH_REQ_DC    = 2'b11;

// ========================================================================
// 0x0F寄存器通道状态上报编码 (datasheet格式)
// ========================================================================
parameter DS_PLAY   = 2'b00;
parameter DS_HI_Z   = 2'b01;
parameter DS_MUTE   = 2'b10;
parameter DS_DC_DIAG = 2'b11;

// ========================================================================
// DC诊断FSM状态编码 (15态)
// ========================================================================
parameter DC_DIAG_IDLE        = 4'd0;
parameter DC_DIAG_OBSERVATION = 4'd1;
parameter DC_DIAG_CH1_S2GP    = 4'd2;
parameter DC_DIAG_CH2_S2GP    = 4'd3;
parameter DC_DIAG_CH3_S2GP    = 4'd4;
parameter DC_DIAG_CH4_S2GP    = 4'd5;
parameter DC_DIAG_CH1_SLICK   = 4'd6;
parameter DC_DIAG_CH2_SLICK   = 4'd7;
parameter DC_DIAG_CH3_SLICK   = 4'd8;
parameter DC_DIAG_CH4_SLICK   = 4'd9;
parameter DC_DIAG_CH1_LO      = 4'd10;
parameter DC_DIAG_CH2_LO      = 4'd11;
parameter DC_DIAG_CH3_LO      = 4'd12;
parameter DC_DIAG_CH4_LO      = 4'd13;
parameter DC_DONE             = 4'd14;

// ========================================================================
// AC诊断FSM状态编码 (6态)
// ========================================================================
parameter AC_DIAG_IDLE = 3'd0;
parameter AC_CH1       = 3'd1;
parameter AC_CH2       = 3'd2;
parameter AC_CH3       = 3'd3;
parameter AC_CH4       = 3'd4;
parameter AC_DONE      = 3'd5;

// ========================================================================
// I2C FSM状态编码 (9态)
// ========================================================================
parameter I2C_IDLE     = 4'd0;
parameter I2C_ADDR     = 4'd1;
parameter I2C_ACK_ADDR = 4'd2;
parameter I2C_WR_ADDR  = 4'd3;
parameter I2C_ACK_WA   = 4'd4;
parameter I2C_WR_DATA  = 4'd5;
parameter I2C_ACK_WD   = 4'd6;
parameter I2C_RD_DATA  = 4'd7;
parameter I2C_ACK_RD   = 4'd8;

// ========================================================================
// I2C设备地址 (7位)
// ========================================================================
parameter I2C_ADDR_00 = 7'h6A;
parameter I2C_ADDR_01 = 7'h6B;
parameter I2C_ADDR_10 = 7'h6C;
parameter I2C_ADDR_11 = 7'h6D;

// ========================================================================
// 时序参数 (CLK_FREQ = 10MHz)
// ========================================================================
parameter DEBOUNCE_CYCLES      = 500;      // STANDBY/MUTE去抖: 50us
parameter FAULT_DEGLITCH_CYCLES = 100;      // 故障去毛刺: 10us
parameter CLK_TIMEOUT_CYCLES   = 24'hFFFFF; // 时钟丢失: ~100ms
parameter DIAG_TIMEOUT_VAL     = 24'hFFFFF; // 诊断超时: ~100ms
parameter OTSD_RECOVERY_CYCLES = 32'hFFFFFF; // OTSD恢复: ~1.68s
parameter DC_OBSERVATION_CYCLES = 24'd10000; // DC观察settle: 1ms

// ========================================================================
// 函数: 通道状态 → 0x0F编码转换
// ========================================================================
function [1:0] ch_state_to_ds;
    input [2:0] state;
    case (state)
        CH_PLAY:          ch_state_to_ds = DS_PLAY;
        CH_HIGH_Z:        ch_state_to_ds = DS_HI_Z;
        CH_MUTE:          ch_state_to_ds = DS_MUTE;
        CH_DC_DIAG_ENTRY: ch_state_to_ds = DS_DC_DIAG;
        CH_AC_DIAG_ENTRY: ch_state_to_ds = DS_HI_Z;  // AC诊断上报为Hi-Z
        default:          ch_state_to_ds = DS_HI_Z;  // IDLE → Hi-Z
    endcase
endfunction

// ========================================================================
// 函数: 只读寄存器判定
// ========================================================================
function is_ro_reg;
    input [7:0] addr;
    case (addr)
        8'h0C, 8'h0D, 8'h0E,         // DC诊断报告
        8'h0F,                         // 通道状态报告
        8'h10, 8'h11, 8'h12, 8'h13,   // 故障/警告
        8'h17, 8'h18, 8'h19, 8'h1A,   // AC诊断报告CH1~4
        8'h1B, 8'h1C, 8'h1D, 8'h1E:   // AC相位/STI
            is_ro_reg = 1'b1;
        default:
            is_ro_reg = 1'b0;
    endcase
endfunction

`endif
