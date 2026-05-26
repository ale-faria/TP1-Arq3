`timescale 1ns / 1ps
import cache_pkg::*;

module cache_controller (
    input  logic                    clk,
    input  logic                    rst_n,

    // Interface com a CPU
    input  logic                    cpu_req_i,
    input  logic [ADDR_WIDTH-1:0]   cpu_addr_i,
    input  logic                    cpu_write_i,
    input  logic [DATA_WIDTH-1:0]   cpu_wdata_i,
    output logic [DATA_WIDTH-1:0]   cpu_rdata_o,
    output logic                    cpu_ready_o,

    // Interface com a Memória Principal
    output logic                    mem_req_o,
    output logic [ADDR_WIDTH-1:0]   mem_addr_o,
    output logic                    mem_write_o,
    output logic [(DATA_WIDTH*BLOCK_SIZE)-1:0] mem_wdata_o,
    input  logic [(DATA_WIDTH*BLOCK_SIZE)-1:0] mem_rdata_i,
    input  logic                    mem_ready_i
);

    logic [TAG_BITS-1:0]   cpu_tag;
    logic [INDEX_BITS-1:0] cpu_index;
    logic [1:0]            word_offset;

    assign cpu_tag     = cpu_addr_i[ADDR_WIDTH-1 : ADDR_WIDTH-TAG_BITS];
    assign cpu_index   = cpu_addr_i[OFFSET_BITS+INDEX_BITS-1 : OFFSET_BITS];
    assign word_offset = cpu_addr_i[3:2];

    cache_state_e current_state, next_state;

    logic                    tag_we;
    logic [TAG_BITS-1:0]     tag_from_cache;
    logic                    valid_from_cache;

    logic                    data_we;
    logic [1:0]              data_word_mask;
    logic [(DATA_WIDTH*BLOCK_SIZE)-1:0] data_from_cache;
    logic [(DATA_WIDTH*BLOCK_SIZE)-1:0] data_to_cache;

    logic cache_hit;
    assign cache_hit = valid_from_cache && (tag_from_cache == cpu_tag);

    assign cpu_rdata_o = (word_offset == 2'b00) ? data_from_cache[31:0]   :
                         (word_offset == 2'b01) ? data_from_cache[63:32]  :
                         (word_offset == 2'b10) ? data_from_cache[95:64]  :
                                                  data_from_cache[127:96];

    tag_array u_tag_array (
        .clk     (clk),
        .rst_n   (rst_n),
        .we_i    (tag_we),
        .index_i (cpu_index),
        .tag_i   (cpu_tag),
        .tag_o   (tag_from_cache),
        .valid_o (valid_from_cache)
    );

    data_array u_data_array (
        .clk       (clk),
        .we_i      (data_we),
        .word_en_i (data_word_mask),
        .index_i   (cpu_index),
        .data_i    (data_to_cache),
        .data_o    (data_from_cache)
    );

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // Usando always @(*) para evitar o bug de constant selects do iverilog antigo
    always @(*) begin
        next_state     = current_state;
        cpu_ready_o    = 1'b0;
        mem_req_o      = 1'b0;
        mem_write_o    = 1'b0;
        mem_addr_o     = cpu_addr_i;
        mem_wdata_o    = '0;

        tag_we         = 1'b0;
        data_we        = 1'b0;
        data_word_mask = 2'b00; 
        data_to_cache  = '0;

        case (current_state)
            
            IDLE: begin
                if (cpu_req_i) begin
                    next_state = COMPARE_TAG;
                end
            end

            COMPARE_TAG: begin
                if (cache_hit) begin 
                    if (cpu_write_i) begin 
                        data_we        = 1'b1;
                        data_word_mask = word_offset; 
                        data_to_cache  = {4{cpu_wdata_i}}; 
                        
                        mem_req_o   = 1'b1;
                        mem_write_o = 1'b1;
                        mem_addr_o  = cpu_addr_i;
                        mem_wdata_o = (word_offset == 2'b00) ? {96'b0, cpu_wdata_i} :
                                      (word_offset == 2'b01) ? {64'b0, cpu_wdata_i, 32'b0} :
                                      (word_offset == 2'b10) ? {32'b0, cpu_wdata_i, 64'b0} :
                                                               {cpu_wdata_i, 96'b0};
                        
                        if (mem_ready_i) begin
                            cpu_ready_o = 1'b1;
                            next_state  = IDLE;
                        end
                    end else begin
                        cpu_ready_o = 1'b1;
                        next_state  = IDLE;
                    end
                end 
                else begin
                    if (cpu_write_i) begin 
                        mem_req_o   = 1'b1;
                        mem_write_o = 1'b1;
                        mem_addr_o  = cpu_addr_i;
                        mem_wdata_o = {4{cpu_wdata_i}};
                        
                        if (mem_ready_i) begin
                            cpu_ready_o = 1'b1;
                            next_state  = IDLE;
                        end
                    end else begin
                        next_state = ALLOCATE;
                    end
                end
            end
            
            ALLOCATE: begin 
                mem_req_o   = 1'b1;
                mem_write_o = 1'b0;
                
                // Mascara matemática (zera os ultimos 4 bits) para alinhar ao bloco
                // Isso evita o erro de sintaxe com fatiamento de bits no simulador
                mem_addr_o  = cpu_addr_i & 32'hFFFFFFF0;
                
                if (mem_ready_i) begin
                    data_we        = 1'b1;
                    data_word_mask = 2'b00; 
                    data_to_cache  = mem_rdata_i;
                    
                    tag_we         = 1'b1;
                    next_state     = RECOVER;
                end
            end

            RECOVER: begin
                next_state = COMPARE_TAG;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule : cache_controller