# 📘 Documentação: Classe TCalculadoraFiscal

> **Localização do Arquivo:** `Unit_CalculoImpostos.pas`

Esta documentação serve como guia de referência para a utilização da classe `TCalculadoraFiscal`, responsável por centralizar a lógica tributária do emissor de NF-e, incluindo as novas regras da **Reforma Tributária (IBS/CBS/IS)**.

---

## 🚀 Como Usar (Guia Rápido)

Para realizar um cálculo, siga este fluxo de 4 passos simples:

1.  **Instancie** a classe.
2.  **Configure** o item (Valores e Quantidades).
3.  **Defina as Regras** (Regime, CST, Alíquotas).
4.  **Execute** `.Calcular` e leia o `.Resultado`.

### 📝 Exemplo de Código

```pascal
uses Unit_CalculoImpostos;

var
  Calc: TCalculadoraFiscal;
begin
  Calc := TCalculadoraFiscal.Create;
  try
    // -------------------------------------------------------
    // 📦 1. DADOS DO ITEM (Entradas Básicas)
    // -------------------------------------------------------
    Calc.ValorProduto        := 1000.00;
    Calc.Quantidade          := 1;
    Calc.ValorFrete          := 50.00;
    Calc.ValorDesconto       := 10.00; // Desconto incondicional

    // -------------------------------------------------------
    // ⚙️ 2. PERFIL DO EMITENTE & PRODUTO
    // -------------------------------------------------------
    Calc.Regime     := rtRegimeNormal;   // ou rtSimplesNacional
    Calc.Origem     := omNacional;       // Origem 0
    Calc.CST_CSOSN  := '10';             // CST 10 (ICMS ST)

    // -------------------------------------------------------
    // 💰 3. ALÍQUOTAS (Sistema Atual)
    // -------------------------------------------------------
    Calc.AliquotaICMS        := 18.00;   // 18%
    Calc.AliquotaIPI         := 5.00;    // 5%
    Calc.AliquotaPIS         := 1.65;
    Calc.AliquotaCOFINS      := 7.60;

    // 🔄 Substituição Tributária (ST)
    Calc.MVA                 := 40.00;   // Margem de Valor Agregado
    Calc.AliquotaInternaST   := 18.00;   // Alíquota destino
    
    // -------------------------------------------------------
    // 🆕 4. REFORMA TRIBUTÁRIA (IBS / CBS / IS)
    // -------------------------------------------------------
    Calc.AliquotaIBS         := 17.00;   // Imposto sobre Bens e Serviços
    Calc.AliquotaCBS         := 9.00;    // Contribuição sobre Bens e Serviços
    Calc.AliquotaIS          := 0.00;    // Imposto Seletivo ("Pecado")

    // -------------------------------------------------------
    // ✅ 5. EXECUTAR & LER
    // -------------------------------------------------------
    Calc.Calcular;

    // Lendo os valores calculados:
    ShowMessage('Base ICMS: ' + CurrToStr(Calc.Resultado.vBC_ICMS));
    ShowMessage('Valor IBS: ' + CurrToStr(Calc.Resultado.vIBS));
    
  finally
    Calc.Free;
  end;
end;
```

---

## 🔑 Propriedades Importantes

Aqui estão as propriedades que você **precisa** preencher para garantir o cálculo correto.

### 📦 Entradas (Valores Monetários)
| Propriedade | Tipo | Obrigatório? | Descrição |
| :--- | :--- | :---: | :--- |
| `ValorProduto` | `Currency` | 🔴 **SIM** | Valor total bruto dos produtos. |
| `Quantidade` | `Double` | 🔴 **SIM** | Quantidade comercializada. |
| `ValorFrete` | `Currency` | ⚪ Opcional | Soma-se à base de cálculo. |
| `ValorSeguro` | `Currency` | ⚪ Opcional | Soma-se à base de cálculo. |
| `ValorDesconto` | `Currency` | ⚪ Opcional | Deduz-se da base de cálculo. |
| `ValorOutrasDespesas`| `Currency` | ⚪ Opcional | Soma-se à base de cálculo. |

### ⚙️ Configuração Fiscal
| Propriedade | Descrição Importante |
| :--- | :--- |
| `Regime` | Define se calcula como **Normal** (CST) ou **Simples** (CSOSN). <br> Valores: `rtRegimeNormal`, `rtSimplesNacional` |
| `CST_CSOSN` | **CRÍTICO:** Define qual fórmula usar. <br> Ex: `'00'` (Tributado Integral), `'10'` (Com ST), `'101'` (Simples c/ Crédito). |
| `Origem` | Origem da Mercadoria (`omNacional`, `omEstrangeira...`). |

---

## 👨‍💻 Autor e Créditos

**Desenvolvido por:** Vitor Scarso  
**GitHub:** [github/vscarso](https://github.com/vscarso)  

Esta classe foi projetada para ser modular e independente, facilitando a integração em projetos existentes sem a necessidade de refatoração profunda.

