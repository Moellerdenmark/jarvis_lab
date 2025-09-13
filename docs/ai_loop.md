# AI Loop

## Prerequisites
- Ollama (11435 eller 11434)
- Python
- Aider venv path

## How to Run tools/ai_loop.ps1
1. Sørg for at Ollama er kørende på den korrekte port.
2. Åbn PowerShell og naviger til mappen der indeholder `tools/ai_loop.ps1`.
3. Kør kommandoen: `.\ai_loop.ps1`.

## Adding a New Task
1. Åbn filen `tools/ai_loop.ps1` i en teksteditor.
2. Tilføj den nye opgave under de eksisterende opgaver.
3. Gem og luk filen.

## Troubleshooting

### Stuck in Multiline (Ctrl+C)
- Tryk `Ctrl+Z` for at afslutte multiline-input.
- Brug `exit` for at afslutte PowerShell-sessionen.

### Missing aider.exe
- Sørg for at `aider.exe` findes i den korrekte venv-path.
- Kør `.\venv\Scripts\activate.ps1` for at aktivere venv'en.

### Failing prove.ps1
- Sjekk loggen for fejlmeddelelser.
- Sørg for alle afhængigheder er installeret korrekt.
