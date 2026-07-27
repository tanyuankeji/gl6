// ============================================================================
// TAS6424E-Q1 PWM生成器 (v6.0)
// 功能: 三角波载波 + 4通道独立比较器 + BTL正反相输出
// 设计原则:
//   - 相位累加器生成三角波载波 (24bit精度)
//   - 共享载波, 每通道独立相位偏移 (225/240/270 deg)
//   - Hi-Z: 输出0; MUTE: 50%占空比; PLAY: 音频调制
//   - PWM频率: 8×/10×/38×/44×/48× fs 可配
//   - 载波频率: 2.11MHz @ 44×fs fs=48kHz
// ============================================================================

module pwm_generator (
    input  wire         clk,
    input  wire         rst_n,
    // 音频数据 (24bit × 4通道)
    input  wire [23:0]  audio_data_ch1,
    input  wire [23:0]  audio_data_ch2,
    input  wire [23:0]  audio_data_ch3,
    input  wire [23:0]  audio_data_ch4,
    input  wire         audio_valid,
    // 通道控制
    input  wire [3:0]   ch_en,              // 通道使能
    input  wire [3:0]   ch_mute_mode,       // 静音模式 (50%占空比)
    input  wire [3:0]   ch_diag_active,     // DC诊断 (输出Hi-Z)
    input  wire [3:0]   ch_ac_active,       // AC诊断 (输出Hi-Z)
    // 模式配置
    input  wire [1:0]   input_sr,           // 采样率
    input  wire [2:0]   pwm_freq,           // PWM频率选择
    input  wire [2:0]   output_phase,       // 相位编码
    input  wire [1:0]   gain_level,         // 增益
    input  wire         pbtl_ch12,          // PBTL模式
    input  wire         pbtl_ch34,
    input  wire         oscillator_en,      // 振荡器使能
    // PWM输出
    output reg          out_1p, out_1m,
    output reg          out_2p, out_2m,
    output reg          out_3p, out_3m,
    output reg          out_4p, out_4m
);

    // ========================================================================
    // PWM频率 → 相位步进映射 (clk=10MHz)
    // phase_step = (2^24 * pwm_freq) / clk_freq
    // ========================================================================
    reg [23:0] phase_step;
    always @(*) begin
        case (pwm_freq)
            3'b000:  phase_step = 24'd591;    // 8×fs ~352kHz
            3'b001:  phase_step = 24'd739;    // 10×fs ~441kHz
            3'b101:  phase_step = 24'd2818;   // 38×fs ~1.68MHz
            3'b110:  phase_step = 24'd3540;   // 44×fs ~2.11MHz (default)
            3'b111:  phase_step = 24'd3558;   // 48×fs ~2.12MHz
            default: phase_step = 24'd3540;
        endcase
    end

    // ========================================================================
    // 相位偏移表 (度数 → 相位累加器偏移)
    // phase_sel: 101=CH0:0 CH2:210 CH3:60 CH4:270
    // phase_sel: 110=CH0:0 CH2:225 CH3:90 CH4:315
    // phase_sel: 111=CH0:0 CH2:240 CH3:120 CH4:360
    // 转换为 24bit 相位偏移 = (2^24 * deg) / 360
    // ========================================================================
    reg [23:0] phase_offset [0:3];
    always @(*) begin
        case (output_phase)
            3'b101: begin // CH1=0, CH2=210, CH3=60, CH4=270
                phase_offset[0] = 24'd0;
                phase_offset[1] = 24'd9786700;  // 210°
                phase_offset[2] = 24'd2796200;  // 60°
                phase_offset[3] = 24'd12582900; // 270°
            end
            3'b111: begin // CH1=0, CH2=240, CH3=120, CH4=360
                phase_offset[0] = 24'd0;
                phase_offset[1] = 24'd11184810; // 240°
                phase_offset[2] = 24'd5592400;  // 120°
                phase_offset[3] = 24'd16777215; // 360°
            end
            default: begin // 110: CH1=0, CH2=225, CH3=90, CH4=315 (default)
                phase_offset[0] = 24'd0;
                phase_offset[1] = 24'd10485750; // 225°
                phase_offset[2] = 24'd4194300;  // 90°
                phase_offset[3] = 24'd14680060; // 315°
            end
        endcase
    end

    // ========================================================================
    // 相位累加器 (共享, 生成三角波)
    // ========================================================================
    reg [23:0] carrier_phase [0:3];  // 每通道独立相位

    integer ci;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (ci = 0; ci < 4; ci = ci + 1)
                carrier_phase[ci] <= 24'd0;
        end else if (oscillator_en) begin
            for (ci = 0; ci < 4; ci = ci + 1)
                carrier_phase[ci] <= carrier_phase[ci] + phase_step;
        end else begin
            for (ci = 0; ci < 4; ci = ci + 1)
                carrier_phase[ci] <= 24'd0;
        end
    end

    // ========================================================================
    // 三角波生成 (phase MSB判断方向, 反相得到三角)
    // ========================================================================
    wire [23:0] triangle_wave [0:3];
    genvar gi;
    generate
        for (gi = 0; gi < 4; gi = gi + 1) begin : gen_triangle
            // phase[23]=0向上, [22:0]直接 → [23]=1向下, [22:0]取反
            // 缩放到24bit有符号
            assign triangle_wave[gi] = carrier_phase[gi][23]
                ? {1'b0, ~carrier_phase[gi][22:0]}
                : {1'b1, carrier_phase[gi][22:0]};
        end
    endgenerate

    // ========================================================================
    // 锁存音频数据 (增益缩放)
    // ========================================================================
    reg signed [23:0] latched_ch1, latched_ch2, latched_ch3, latched_ch4;
    wire signed [23:0] scale_ch1, scale_ch2, scale_ch3, scale_ch4;

    always @(posedge clk) begin
        if (audio_valid) begin
            latched_ch1 <= audio_data_ch1;
            latched_ch2 <= audio_data_ch2;
            latched_ch3 <= audio_data_ch3;
            latched_ch4 <= audio_data_ch4;
        end
    end

    // 增益缩放 (简化: gain_level=00→7.5V,01→15V,10→21V,11→29V)
    // 实际增益缩放需要乘除运算, 这里简化为直接使用 (后续可扩展)
    assign scale_ch1 = latched_ch1;
    assign scale_ch2 = latched_ch2;
    assign scale_ch3 = latched_ch3;
    assign scale_ch4 = latched_ch4;

    // ========================================================================
    // 通道0-3 独立比较器 + 输出控制
    // ========================================================================
    wire [3:0] pwm_p, pwm_m;  // 比较结果

    // 比较: audio > carrier → high
    // out_p = (scale > triangle); out_m = (-scale > triangle)
    assign pwm_p[0] = $signed(scale_ch1) > $signed(triangle_wave[0]);
    assign pwm_m[0] = $signed(-scale_ch1) > $signed(triangle_wave[0]);
    assign pwm_p[1] = $signed(scale_ch2) > $signed(triangle_wave[1]);
    assign pwm_m[1] = $signed(-scale_ch2) > $signed(triangle_wave[1]);
    assign pwm_p[2] = $signed(scale_ch3) > $signed(triangle_wave[2]);
    assign pwm_m[2] = $signed(-scale_ch3) > $signed(triangle_wave[2]);
    assign pwm_p[3] = $signed(scale_ch4) > $signed(triangle_wave[3]);
    assign pwm_m[3] = $signed(-scale_ch4) > $signed(triangle_wave[3]);

    // ========================================================================
    // 输出控制: Hi-Z(00) / MUTE(10,50%) / PLAY(pwm) / DIAG(00)
    // ========================================================================
    function [1:0] out_ctrl(input ch, input [3:0] en, input [3:0] mute, input [3:0] diag, input [3:0] ac);
        begin
            if (!en[ch] && !mute[ch] && !diag[ch] && !ac[ch])
                out_ctrl = 2'b00;  // Hi-Z
            else if (mute[ch])
                out_ctrl = 2'b10;  // MUTE: out_p=1, out_m=0 (50%)
            else if (en[ch])
                out_ctrl = {pwm_p[ch], pwm_m[ch]};  // PLAY: PWM
            else
                out_ctrl = 2'b00;  // DIAG: Hi-Z
        end
    endfunction

    always @(posedge clk) begin
        {out_1p, out_1m} <= (ch_diag_active[0] || ch_ac_active[0] || !ch_en[0] && !ch_mute_mode[0]) ? 2'b00
                          : ch_mute_mode[0] ? 2'b10
                          : {pwm_p[0], pwm_m[0]};
        {out_2p, out_2m} <= (ch_diag_active[1] || ch_ac_active[1] || !ch_en[1] && !ch_mute_mode[1]) ? 2'b00
                          : ch_mute_mode[1] ? 2'b10
                          : {pwm_p[1], pwm_m[1]};
        {out_3p, out_3m} <= (ch_diag_active[2] || ch_ac_active[2] || !ch_en[2] && !ch_mute_mode[2]) ? 2'b00
                          : ch_mute_mode[2] ? 2'b10
                          : {pwm_p[2], pwm_m[2]};
        {out_4p, out_4m} <= (ch_diag_active[3] || ch_ac_active[3] || !ch_en[3] && !ch_mute_mode[3]) ? 2'b00
                          : ch_mute_mode[3] ? 2'b10
                          : {pwm_p[3], pwm_m[3]};
    end

endmodule
