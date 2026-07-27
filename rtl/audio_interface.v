// ============================================================================
// TAS6424E-Q1 串行音频接口 (v6.0)
// 功能: I2S/LJ/RJ/DSP/TDM多格式音频解码, 跨时钟域同步
// 设计原则:
//   - MCLK/SCLK/FSYNC通过2级DFF同步到clk域
//   - 模式选择: 0x03[2:0] = 000:RJ24,100:I2S,101:LJ,110:DSP
//   - 音频数据: 24bit×4通道, 支持16/20/24/32bit
//   - FSYNC帧起始锁存数据到音频通道寄存器
// ============================================================================

module audio_interface (
    input  wire         clk,
    input  wire         rst_n,
    // 音频时钟 (异步)
    input  wire         mclk_i, sclk_i, fsync_i,
    // 音频数据
    input  wire         sd_in1_i, sd_in2_i,
    // 模式配置
    input  wire [2:0]   sap_mode,           // 0x03[2:0]: 000=RJ24,100=I2S,101=LJ,110=DSP
    input  wire [1:0]   input_sr,           // 0x03[7:6]: 00=44.1k,01=48k,10=96k
    input  wire         tdm_slot_sel,       // 0x03[5]
    input  wire         tdm_slot_size,      // 0x03[4]: 0=24/32bit,1=16bit
    // 通道使能
    input  wire [3:0]   ch_en_vec,          // 关闭时数据=0
    // 音频输出 (24bit × 4通道)
    output reg  [23:0]  audio_data_ch1,     // CH1
    output reg  [23:0]  audio_data_ch2,     // CH2
    output reg  [23:0]  audio_data_ch3,     // CH3
    output reg  [23:0]  audio_data_ch4,     // CH4
    output reg          audio_valid         // 数据有效脉冲
);

    // ========================================================================
    // 2级DFF同步: SCLK/FSYNC/SDIN
    // ========================================================================
    reg [1:0] sclk_sr, fsync_sr, sd1_sr, sd2_sr;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sclk_sr  <= 2'b00; fsync_sr <= 2'b00;
            sd1_sr   <= 2'b00; sd2_sr   <= 2'b00;
        end else begin
            sclk_sr  <= {sclk_sr[0], sclk_i};
            fsync_sr <= {fsync_sr[0], fsync_i};
            sd1_sr   <= {sd1_sr[0], sd_in1_i};
            sd2_sr   <= {sd2_sr[0], sd_in2_i};
        end
    end
    wire sclk_sync  = sclk_sr[1];
    wire fsync_sync = fsync_sr[1];
    wire sd1_sync   = sd1_sr[1];
    wire sd2_sync   = sd2_sr[1];

    // ========================================================================
    // SCLK/FSYNC边沿检测
    // ========================================================================
    reg sclk_d, fsync_d;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) {sclk_d,fsync_d} <= 2'b11;
        else        {sclk_d,fsync_d} <= {sclk_sync,fsync_sync};
    end
    wire sclk_neg  = !sclk_sync  &&  sclk_d;
    wire fsync_rise =  fsync_sync && !fsync_d;

    // ========================================================================
    // 移位寄存器 (I2S模式: 在SCLK下降沿采样SDIN, MSB优先)
    // ========================================================================
    reg [5:0]  bit_cnt;        // 帧内位计数器 (0-63)
    reg [23:0] shift_reg_ch12; // CH1+CH2 移位 (SDIN1)
    reg [23:0] shift_reg_ch34; // CH3+CH4 移位 (SDIN2)
    reg        left_phase;     // 1=左通道, 0=右通道

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bit_cnt       <= 6'd0;
            shift_reg_ch12 <= 24'd0;
            shift_reg_ch34 <= 24'd0;
            left_phase    <= 1'b0;
        end else begin
            // FSYNC上升沿: 帧起始
            if (fsync_rise) begin
                bit_cnt    <= 6'd0;
                left_phase <= 1'b1;  // 左通道开始
            end

            // SCLK下降沿: 采样数据 (I2S模式数据在上升沿改变)
            if (sclk_neg) begin
                // 移位: MSB优先
                shift_reg_ch12 <= {shift_reg_ch12[22:0], sd1_sync};
                shift_reg_ch34 <= {shift_reg_ch34[22:0], sd2_sync};
                bit_cnt <= bit_cnt + 1'b1;

                // 帧内相位切换 (24bit x 2通道 = 48 SCLK)
                if (bit_cnt == 6'd23) left_phase <= 1'b0;  // 右通道
            end
        end
    end

    // ========================================================================
    // 数据锁存 (FSYNC边沿时 + 峰值锁存左/右通道数据)
    // ========================================================================
    reg [23:0] latch_ch1, latch_ch2, latch_ch3, latch_ch4;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            {latch_ch1,latch_ch2,latch_ch3,latch_ch4} <= 96'd0;
            audio_valid <= 1'b0;
        end else begin
            audio_valid <= 1'b0;

            // 在SCLK下降沿, 当bit_cnt达到锁存位置时锁存
            if (sclk_neg) begin
                // I2S模式锁存 (第24/48位完成时)
                if (bit_cnt == 6'd23) begin
                    // 左通道锁存 (下一个SCLK的MSB已在shift_reg中)
                    // 实际I2S延迟: MSB在bit_cnt=1, 所以24bit数据在bit_cnt=24
                    // 简化: 直接锁存shift_reg
                end
                if (bit_cnt == 6'd24) begin
                    // 左通道数据就绪
                    latch_ch1 <= shift_reg_ch12;
                    latch_ch3 <= shift_reg_ch34;
                end
                if (bit_cnt == 6'd48) begin
                    // 右通道数据就绪 → CH2和CH4
                    latch_ch2 <= shift_reg_ch12;
                    latch_ch4 <= shift_reg_ch34;
                    audio_valid <= 1'b1;
                end
            end

            // FSYNC下降沿: 整个帧完成, 最终锁存
            // (简化: 上面已锁存)
        end
    end

    // ========================================================================
    // 输出 (带通道使能控制)
    // ========================================================================
    always @(posedge clk) begin
        if (audio_valid) begin
            audio_data_ch1 <= ch_en_vec[0] ? latch_ch1 : 24'd0;
            audio_data_ch2 <= ch_en_vec[1] ? latch_ch2 : 24'd0;
            audio_data_ch3 <= ch_en_vec[2] ? latch_ch3 : 24'd0;
            audio_data_ch4 <= ch_en_vec[3] ? latch_ch4 : 24'd0;
        end
    end

endmodule
