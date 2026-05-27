# Trabalho Prático 1 - Controlador de Cache

## Descrição do Projeto
Implementação em Verilog de um controlador de cache com mapeamento direto, política de escrita *Write-Through* em caso de *hit*, e *No-Write-Allocate* em caso de *miss*. O projeto inclui uma memória principal simulada e um testbench automatizado para validação de Read Path, Write Path e conflitos de mapeamento.

## Dependências Necessárias
Para compilar e simular este projeto no Linux, você precisará de:
* **Icarus Verilog** (Compilador/Simulador)
* **GTKWave** (Visualizador de Waveforms)
* **Make** (Para automação)

## Instruções de Execução
No terminal, dentro da pasta `src`, execute os comandos:
1. `make clean` (Para limpar os arquivos gerados pela compilação e simulação)
2. `make compile` (Para compilar o código fonte e testbenches)
3. `make run` (Para rodar a simulação e gerar os logs no terminal)
4. `make view` (Para abrir as formas de onda da simulação no GTKWave)