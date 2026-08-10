# wav_para_hz

Converte arquivos de áudio `.mp3`, `.mp4` e `.wav` em frequências para gerar dados no formato utilizado pelo:

```text
GRUB_INIT_TUNE=
```

Projeto desenvolvido através de testes e experimentos com auxílio de:

* ChatGPT
* Gemini
* Manus

---

## Objetivo

O projeto analisa um arquivo de áudio, identifica frequências utilizando **STFT (Short-Time Fourier Transform)** e transforma essas frequências em uma sequência de notas com duração.

O resultado pode ser utilizado para gerar:

```bash
GRUB_INIT_TUNE="1200 ..."
```

Também é possível gerar um WAV sintetizado a partir das frequências detectadas, permitindo ouvir o resultado da análise.

---

## Fluxo do processamento

```text
.mp3 / .mp4 / .wav
        │
        ▼
     FFmpeg
        │
        ▼
 WAV PCM 8-bit
        │
        ▼
     stft.py
        │
        ├── análise STFT
        │
        ├── identificação das frequências
        │
        ├── seleção dos TOP_N sons
        │
        └── rastreamento das frequências
        │
        ▼
*-notas.txt
*-grub.txt
        │
        ▼
notas_para_grub.sh
        │
        ├── agrupamento das notas
        │
        └── geração do GRUB_INIT_TUNE
        │
        ▼
work/grub/*-grub.txt

        └──────────────────────► notas_para_wav.sh
                                      │
                                      ▼
                              WAV sintetizado
```

---

# Estrutura do projeto

```text
wav_para_hz_code_v2/
├── main.sh
├── run.sh
├── config.sh
├── stft.py
├── notas_para_grub.sh
├── notas_para_wav.sh
└── in/
```

Durante a execução são criadas as pastas:

```text
out/
├── ffmpeq/
├── notas/
├── grub/
├── wav/
└── log/

work/
├── notas/
├── notas2/
├── notas3/
├── grub/
├── wav/
├── tmp/
└── block/
```

---

# Requisitos

O projeto utiliza:

* Bash
* Python 3
* NumPy
* SciPy
* FFmpeg
* SoX

Para verificar algumas das ferramentas:

```bash
python3 --version
ffmpeg -version
sox --version
```

As bibliotecas Python utilizadas pelo `stft.py` são:

```python
import numpy
from scipy.io import wavfile
from scipy.signal import stft, istft
```

Portanto, é necessário ter **NumPy** e **SciPy** instalados.

Download **NumPy** e **SciPy**

```bash
pip install numpy scipy
```
ou
```bash
sudo apt install python3-numpy python3-scipy

```

Download sox
```bash
sudo apt install sox libsox-fmt-all
```

Download ffmpeg
```bash
sudo apt install ffmpeg
```

---

# Configuração

As principais configurações ficam em:

```text
config.sh
```

Configuração atual:

```bash
sample_rate=44100
channels=1
bits=8

janela_ms=10

fft_nperseg=441
fft_overlap=220

awk_hz_max=1200.00

# python
python_janela_ms=100
python_overlap=50
python_limiar=0.5
python_top_n=5
python_tolerancia_hz=30
```

---

## Sample rate

```bash
sample_rate=44100
```

Define a taxa de amostragem utilizada na conversão para WAV.

---

## Canais

```bash
channels=1
```

O áudio é convertido para mono.

---

## Bits

```bash
bits=8
```

A conversão realizada pelo FFmpeg utiliza:

```bash
-c:a pcm_u8
```

Portanto, o WAV intermediário utilizado pelo STFT é PCM unsigned 8-bit.

---

# Configuração do STFT

## Janela

```bash
python_janela_ms=100
```

A janela utilizada pelo `stft.py` atualmente é de:

```text
100 ms
```

O código calcula o número de amostras automaticamente:

```python
JANELA = max(32, int(fs * (JANELA_MS / 1000)))
```

Com `44100 Hz`:

```text
44100 × 0,1 = 4410 amostras
```

---

## Overlap

```bash
python_overlap=50
```

Representa:

```text
50%
```

de sobreposição entre as janelas do STFT.

---

# Limiar

```bash
python_limiar=0.5
```

O limiar determina a amplitude mínima para que uma frequência seja considerada.

No `stft.py`:

```python
if amp[indice] < LIMIAR:
    continue
```

Por isso, o valor do limiar influencia diretamente a quantidade de frequências encontradas.

Durante os testes, valores como:

```bash
#python_limiar=5.0
#python_limiar=1.0
python_limiar=0.5
#python_limiar=0.1
```

foram utilizados para experimentar diferentes níveis de detecção.

Um limiar muito alto pode fazer com que determinadas janelas não tenham nenhuma frequência válida.

Quando isso acontece, o arquivo `*-grub.txt` pode conter:

```text
0.00 0.00 0.00 0.00 0.00
```

---

# TOP_N

A configuração atual é:

```bash
python_top_n=5
```

Isso significa que o STFT pode selecionar até **5 frequências principais por bloco**.

Por exemplo:

```text
130.00 50.00 150.00 0.00 0.00
```

Cada coluna representa um dos possíveis sons:

```text
som 1
som 2
som 3
som 4
som 5
```

Os valores `0.00` representam slots sem uma frequência detectada.

---

# Tolerância

A configuração atual é:

```bash
python_tolerancia_hz=30
```

A tolerância é utilizada para tentar manter uma frequência de um bloco para o próximo.

No `stft.py`:

```python
distancia = abs(freq - freq_anterior)

if distancia <= melhor_distancia:
    melhor = indice
```

Assim, uma frequência próxima da frequência anterior pode continuar no mesmo slot.

Exemplo:

```text
470 Hz
480 Hz
```

A diferença é:

```text
10 Hz
```

Como:

```text
10 <= 30
```

a frequência pode ser considerada continuidade do mesmo som.

---

# Seleção dos sons

O `stft.py` primeiro encontra picos locais:

```python
if amp[indice] >= amp[indice - 1] and \
   amp[indice] >= amp[indice + 1]:
```

Depois os candidatos são ordenados pela amplitude:

```python
candidatos.sort(
    key=lambda x: amp[x],
    reverse=True
)
```

E limitados ao número definido por:

```bash
python_top_n=5
```

Depois o programa tenta manter os sons anteriores antes de preencher os slots vazios com novos candidatos.

---

# Lógica dos slots

Com:

```text
TOP_N=5
```

os slots são:

```text
1 → 2 → 3 → 4 → 5
```

A lógica utilizada posteriormente no processamento das notas procura o próximo som quando o atual estiver zerado.

Exemplo:

```text
começa o loop
    │
    ├── som 1 = 0
    │       ↓
    │   procura som 2
    │
    ├── som 2 = 0
    │       ↓
    │   procura som 3
    │
    ├── som 3 = 150
    │
    └── fim do loop
```

Resultado:

```text
150
```

No próximo bloco, a procura continua a partir do próximo slot:

```text
começa novo loop
    │
    ├── som 4 = 0
    │       ↓
    │   procura som 5
    │
    ├── som 5 = 0
    │       ↓
    │   procura som 1
    │
    ├── som 1 = 0
    │       ↓
    │   procura som 2
    │
    ├── som 2 = 0
    │       ↓
    │   procura som 3
    │
    ├── som 3 = 0
    │
    └── fim do loop
```

A procura utiliza os slots de forma circular:

```text
1 → 2 → 3 → 4 → 5 → 1 → 2 → ...
```

Isso permite continuar a procura sem ficar preso em um único slot.

Se todos os sons estiverem em `0`, a procura termina sem encontrar uma frequência válida.

---

# Limite de frequência

A configuração:

```bash
awk_hz_max=1200.00
```

define o limite utilizado posteriormente pelo `notas_para_grub.sh`.

Frequências acima desse limite são transformadas em zero durante o processamento das notas.

Por exemplo:

```text
1410 Hz
```

pode ser transformado em:

```text
0 Hz
```

quando o limite está configurado como:

```text
1200 Hz
```

---

# Execução

Coloque os arquivos de entrada em:

```text
in/
```

Por exemplo:

```text
in/musica.mp3
```

Depois execute:

```bash
./run.sh
```

O `run.sh` executa as etapas necessárias do processamento.

---

# main.sh

O `main.sh` realiza a primeira etapa.

Para cada arquivo encontrado em:

```text
in/
```

o FFmpeg converte o áudio para WAV:

```bash
ffmpeg \
-i "$arquivo" \
-vn \
-ar "$sample_rate" \
-ac "$channels" \
-c:a pcm_u8 \
"$wavout/ffmpeq/$nome-ffmpeg.wav"
```

Depois o WAV é enviado para:

```text
stft.py
```

---

# stft.py

O `stft.py` realiza a análise de frequência.

Ele recebe:

```text
entrada.wav
notas.txt
grub.txt
saida
janela_ms
overlap
limiar
top_n
tolerancia_hz
```

Exemplo:

```bash
python3 stft.py \
entrada.wav \
notas.txt \
grub.txt \
saida \
100 \
50 \
0.5 \
5 \
30
```

Ele gera:

```text
notas.txt
grub.txt
saida.wav
```

---

# Arquivo de notas

O arquivo:

```text
*-notas.txt
```

contém as frequências detectadas pelo STFT, juntamente com amplitude e fase.

Exemplo:

```text
Tempo=0.0500s

440.00Hz amp=...
fase=...
```

---

# Arquivo GRUB intermediário

O arquivo:

```text
*-grub.txt
```

contém as frequências selecionadas para cada bloco.

Exemplo:

```text
# tempo_bloco=0.050000
# top_n=5

130.00 50.00 150.00 0.00 0.00
0.00 60.00 0.00 0.00 0.00
200.00 70.00 330.00 260.00 0.00
```

O tempo de cada bloco é definido pelo STFT.

Com:

```text
# tempo_bloco=0.050000
```

cada linha representa aproximadamente:

```text
0,05 segundo
```

---

# notas_para_grub.sh

Esse script pega o:

```text
out/grub/*-grub.txt
```

e transforma as frequências em sequências agrupadas.

Por exemplo, uma sequência:

```text
440 1
440 1
440 1
440 1
440 1
```

pode ser agrupada como:

```text
440 5
```

Isso reduz a quantidade de elementos necessários no resultado final.

O script gera:

```text
work/notas/
work/notas2/
work/notas3/
work/grub/
```

---

# GRUB_INIT_TUNE

O resultado final é gerado no formato:

```bash
GRUB_INIT_TUNE="1200 ..."
```

O primeiro valor utilizado pelo script é:

```text
1200
```

seguido pelos pares:

```text
frequência duração
```

Por exemplo:

```bash
GRUB_INIT_TUNE="1200 440 10 0 5 523 8"
```

A estrutura é:

```text
GRUB_INIT_TUNE="BEEP FREQUÊNCIA DURAÇÃO FREQUÊNCIA DURAÇÃO ..."
```

---

# notas_para_wav.sh

Além do `GRUB_INIT_TUNE`, o projeto também consegue gerar um WAV sintetizado a partir das notas.

O script utiliza:

```text
SoX
```

Para frequências abaixo de `40 Hz`, é gerado silêncio.

Para frequências a partir de `40 Hz`, é sintetizada uma onda quadrada.

Os blocos são posteriormente concatenados em um único WAV.

---

# Arquivos gerados

Após a execução, os principais resultados ficam em:

```text
out/
```

### FFmpeg

```text
out/ffmpeq/
```

Contém os WAVs intermediários convertidos pelo FFmpeg.

### Notas

```text
out/notas/
```

Contém os resultados detalhados da análise do STFT.

### GRUB

```text
out/grub/
```

Contém as frequências selecionadas por bloco.

### WAV

```text
out/wav/
```

Contém o WAV reconstruído pelo `stft.py`.

### Logs

```text
out/log/
```

Contém os logs do FFmpeg.

---

# Diretório `work`

Os scripts posteriores utilizam:

```text
work/
```

para armazenar os resultados intermediários.

Entre eles:

```text
work/notas/
work/notas2/
work/notas3/
work/grub/
work/wav/
```

Os diretórios:

```text
work/tmp/
work/block/
```

são utilizados temporariamente pelo `notas_para_wav.sh`.

---

## 🌐 Website — Visualizador de Notas Musicais

O projeto também possui um Website criado com auxílio do Manus para visualizar os resultados da análise.

👉 **[Abrir Visualizador de Notas Musicais](https://notewiz-y4mzpsb5.manus.space)**

O visualizador permite:

- visualizar as notas;
- visualizar a sequência das notas;
- fazer download dos resultados.

Website desenvolvido com auxílio do Manus.

---

# Resumo

O projeto realiza:

```text
Áudio
  ↓
FFmpeg
  ↓
WAV PCM 8-bit
  ↓
STFT
  ↓
Frequências
  ↓
TOP_N
  ↓
Tolerância
  ↓
*-grub.txt
  ↓
Agrupamento
  ↓
GRUB_INIT_TUNE
```

E também:

```text
*-notas2.txt
      ↓
notas_para_wav.sh
      ↓
WAV sintetizado
```

---

# Desenvolvimento

Este projeto foi desenvolvido através de diferentes versões e experimentos.

O histórico inclui:

```text
wav_para_hz.sh
        ↓
wav_para_hz2.sh
        ↓
experimentos de análise de frequência
        ↓
geração de GRUB_INIT_TUNE
        ↓
geração de WAV de beep
        ↓
STFT
        ↓
wav_para_hz_code_v2
```

Desenvolvimento e testes realizados com auxílio de:

```text
#chatgpt
#gemini
#manus
```

---

# Observação

Os valores de:

```bash
python_janela_ms
python_overlap
python_limiar
python_top_n
python_tolerancia_hz
awk_hz_max
```

podem alterar significativamente o resultado da análise.

Em especial, o:

```bash
python_limiar
```

influencia diretamente quais frequências são consideradas pelo STFT.

Durante os testes, foi observado que um limiar muito alto, como:

```bash
python_limiar=5.0
```

pode fazer com que muitos blocos não apresentem frequências detectadas.

Por isso, a configuração atualmente utilizada é:

```bash
python_limiar=0.5
python_top_n=5
python_tolerancia_hz=30
```
