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
    // ---- PARA FACILITAR OS TESTES ----
    // essas funções evitam  repitir as mesmas 10 linhas de codigo para cada leitura/escrita
    task automatic do_read(input logic [31:0] addr);
        $display("[%0t] READ  -> Endereco: 0x%08h", $time, addr);
        cpu_req = 1;
        cpu_write = 0;
        cpu_addr = addr;
        wait(cpu_ready == 1); // Fica travado aqui até a cache avisar que terminou
        @(posedge clk);
        cpu_req = 0;
        #10;
    endtask

    task automatic do_write(input logic [31:0] addr, input logic [31:0] data);
        $display("[%0t] WRITE -> Endereco: 0x%08h | Dado: 0x%08h", $time, addr, data);
        cpu_req = 1;
        cpu_write = 1;
        cpu_addr = addr;
        cpu_wdata = data;
        wait(cpu_ready == 1);
        @(posedge clk);
        cpu_req = 0;
        cpu_write = 0;
        #10;
    endtask

    // ---- ROTINA PRINCIPAL DE TESTES ----
    initial begin
        // arquivo para o GTKWave
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_cache);

        // 1 inicializacao (estado vazio) 
        clk = 0;
        rst_n = 0;
        cpu_req = 0;
        cpu_addr = 0;
        cpu_write = 0;
        cpu_wdata = 0;

        #15 rst_n = 1;
        #10;

        $display("\n--- INICIANDO BATERIA DE TESTES ---");

        // ========================================================= //
        // 7.1 testes de leitura (read path)
        // ========================================================= //
        $display("\n[TESTE 7.1] Leitura - Miss seguido de Hit");
        do_read(32'h00000000);  // MISS: busca o bloco 0 na memória
        do_read(32'h00000000);  // HIT: ta na cache

        // ========================================================= //
        // 7.2 teste de escrita (write path)
        // ========================================================= //
        $display("\n[TESTE 7.2] Escrita - Hit (Write-Through) e Miss (No-Write-Allocate)");
        // escreve em um endereço que já está na cache (Hit)
        do_write(32'h00000004, 32'h00000207); 
        
        // escreve em um bloco que NÃO está na cache (Miss)
        // pela nossa implementacao, vai direto para a mem e não traz o bloco
        do_write(32'h00000040, 32'h000000F1); 

        // ========================================================= //
        // 7.3 e 7.4 testes de substituição e consistência (conflito de indice)
        // ========================================================= //
        $display("\n[TESTE 7.3 e 7.4] Conflito de Mapeamento (Substituicao de Bloco)")
        // enderecos 0x00000010 e 0x00000410 mapeiam para o MESMO índice (linha 1 da cache)
        // mas possuem tags diferentes, acessar em sequência força a expulsão do bloco
        do_read(32'h00000010);  // MISS: carrega tag 0 na linha 1
        do_read(32'h00000410);  // MISS: expulsa tag 0 e carrega tag 1 na linha 1
        do_read(32'h00000010);  // MISS: expulsa tag 1 e carrega tag 0 dnv (evidência do conflito)

        // ========================================================= //
        // 7.5 testes de casos limite
        // ========================================================= //
        $display("\n[TESTE 7.5] Acesso a Endereco Extremo");
        // endereço na ultima posição possível de 32 bits (alinhado a palavra)
        do_read(32'hFFFFFFF0);

        $display("\n--- SIMULACAO CONCLUIDA COM SUCESSO ---");
        $finish;
    end

endmodule