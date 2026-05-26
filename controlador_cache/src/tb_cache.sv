`timescale 1ns / 1ps
import cache_pkg::*;

module tb_cache;

    // sinais de clock e reset
    logic clk;
    logic rst_n;

    // sinais CPU <-> cache
    logic                    cpu_req;
    logic [ADDR_WIDTH-1:0]   cpu_addr;
    logic                    cpu_write;
    logic [DATA_WIDTH-1:0]   cpu_wdata;
    logic [DATA_WIDTH-1:0]   cpu_rdata;
    logic                    cpu_ready;

    // sinais cache <-> memoria principal
    logic                    mem_req;
    logic [ADDR_WIDTH-1:0]   mem_addr;
    logic                    mem_write;
    logic [(DATA_WIDTH*BLOCK_SIZE)-1:0] mem_wdata;
    logic [(DATA_WIDTH*BLOCK_SIZE)-1:0] mem_rdata;
    logic                    mem_ready;

    // 1 instanciação da cache
    cache_controller u_cache (
        .clk         (clk),
        .rst_n       (rst_n),
        .cpu_req_i   (cpu_req),
        .cpu_addr_i  (cpu_addr),
        .cpu_write_i (cpu_write),
        .cpu_wdata_i (cpu_wdata),
        .cpu_rdata_o (cpu_rdata),
        .cpu_ready_o (cpu_ready),
        .mem_req_o   (mem_req),
        .mem_addr_o  (mem_addr),
        .mem_write_o (mem_write),
        .mem_wdata_o (mem_wdata),
        .mem_rdata_i (mem_rdata),
        .mem_ready_i (mem_ready)
    );

    // 2 instanciação da memoria principal (mock)
    mock_memory u_mem (
        .clk         (clk),
        .rst_n       (rst_n),
        .mem_req_i   (mem_req),
        .mem_addr_i  (mem_addr),
        .mem_write_i (mem_write),
        .mem_wdata_i (mem_wdata),
        .mem_rdata_o (mem_rdata),
        .mem_ready_o (mem_ready)
    );

    // geacao de clock (periodo: 10ns)
    always #5 clk = ~clk;

    // 3 rotina principal de testes
    initial begin
        // configuração para gerar o arquivo de simulação para o GTKWave
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_cache);

        // estado inicial (reset)
        clk = 0;
        rst_n = 0;
        cpu_req = 0;
        cpu_addr = 0;
        cpu_write = 0;
        cpu_wdata = 0;

        // aguarda 15ns e desliga o reset
        #15;
        rst_n = 1;
        #10;

        $display("--- INICIANDO SIMULACAO DA CACHE ---");

        // ========================================================= //
        // TESTE 1: miss de leitura (read miss) 
        // A cache ta vazia, pede o endereço 0x00 para a mem
        // ========================================================= //
        $display("Iniciando Teste 1: Read Miss [Endereço: 0x00000000]");
        cpu_req = 1;
        cpu_write = 0;
        cpu_addr = 32'h00000000;
        
        // comando do testbench para esperar a cache avisar que terminou
        wait(cpu_ready == 1); 
        @(posedge clk);
        cpu_req = 0; // desliga a requisição
        #20; // pausa dramática para ver bonito na onda hehe

        // ========================================================= //
        // TESTE 2: hit de leitura (read hit)
        // Pede o MESMO endereço, a cache deve responder imediatamente
        // ========================================================= //
        $display("Iniciando Teste 2: Read Hit [Endereço: 0x00000000]");
        cpu_req = 1;
        cpu_write = 0;
        cpu_addr = 32'h00000000;
        
        wait(cpu_ready == 1);
        @(posedge clk);
        cpu_req = 0;
        #20;

        // ========================================================= //
        // TESTE 3: hite de escrita (write hit write-through)
        // escreve um valor na próxima palavra do mesmo bloco
        // ========================================================= //
        $display("Iniciando Teste 3: Write Hit [Endereço: 0x00000004]");
        cpu_req = 1;
        cpu_write = 1; // agora é escrita
        cpu_addr = 32'h00000004;
        cpu_wdata = 32'hDEADBEEF;
        
        wait(cpu_ready == 1);
        @(posedge clk);
        cpu_req = 0;
        cpu_write = 0;
        #20;

        $display("--- SIMULACAO CONCLUIDA COM SUCESSO ---");
        $finish; // encerra a simulação
    end

endmodule