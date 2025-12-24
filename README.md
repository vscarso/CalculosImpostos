# 📘 Manual Completo da Calculadora Fiscal (NFe / NFCe)

> **Autor:** Vitor Scarso  
> **Versão:** 1.1 (Detalhada)  
> **Data:** 24/12/2025

---

## 🎯 O que é esta classe?

A `TCalculadoraFiscal` é o coração do cálculo tributário. Ela resolve a complexidade de calcular bases de cálculo, reduções, MVA ajustada, DIFAL e as novas regras da Reforma Tributária, tudo em um único lugar.

---

## 📋 1. Campos Obrigatórios (O que preciso preencher?)

Para que a calculadora funcione corretamente, você deve preencher os campos de acordo com o grupo de imposto que deseja calcular.

### 📦 A. Dados Básicos do Produto (Sempre Obrigatórios)
Estes campos formam a base de cálculo de todos os impostos.

| Propriedade | Tipo | Descrição |
| :--- | :--- | :--- |
| `ValorProduto` | Currency | Valor unitário * quantidade (valor bruto do item). |
| `Quantidade` | Double | Quantidade comercializada (usado para IPI de Pauta). |
| `ValorFrete` | Currency | (Opcional) Soma na base do ICMS, PIS, COFINS e IPI. |
| `ValorSeguro` | Currency | (Opcional) Soma na base. |
| `ValorOutrasDespesas` | Currency | (Opcional) Soma na base. |
| `ValorDesconto` | Currency | (Opcional) Abate da base. |

### 🏛️ B. Configuração de Regime
Define como o cálculo se comporta (Normal ou Simples).

| Propriedade | Valores |
| :--- | :--- |
| `Regime` | `rtRegimeNormal` ou `rtSimplesNacional` |

---

### 📉 C. Campos por Imposto

#### 1. ICMS Normal (Próprio)
*Necessário para CSTs: 00, 20, 51, 90, etc.*
*   `CST_CSOSN`: Código da Situação Tributária (Ex: '00', '20').
*   `AliquotaICMS`: Alíquota interna ou interestadual (Ex: 18.00).
*   *(Opcional)* `ReducaoBaseICMS`: Percentual de redução (Ex: 33.33).
*   *(Opcional)* `AliquotaDiferimento`: Para CST 51 (Ex: 100 para diferimento total).

#### 2. ICMS ST (Substituição Tributária)
*Necessário para CSTs: 10, 30, 70, 201, 202, etc.*
*   `CST_CSOSN`: Ex: '10'.
*   `MVAOriginal`: Margem de Valor Agregado original (Ex: 40.00).
*   `AliquotaInternaST`: Alíquota interna do estado de destino (Ex: 18.00).
*   `AliquotaICMS`: Alíquota interestadual (usada para abater o ICMS próprio).
*   *(Opcional)* `AutoAjustarMVA`: Se `True`, ajusta a MVA automaticamente para operações interestaduais.

#### 3. PIS e COFINS
*   `CST_PIS` e `CST_COFINS`: Ex: '01' (Tributado) ou '06' (Isento).
*   `AliquotaPIS`: Ex: 1.65.
*   `AliquotaCOFINS`: Ex: 7.60.

#### 4. IPI
*   `CST_IPI`: Ex: '50' (Tributado).
*   `AliquotaIPI`: Ex: 10.00.

#### 5. Reforma Tributária (IBS / CBS / IS)
*   `CST_IBS` e `CST_CBS`: Novos códigos (Ex: '01' Tributado, '04' Isento).
*   `AliquotaCBS`: Ex: 0.90.
*   `AliquotaIBS_UF`: Alíquota Estadual (Ex: 10.00).
*   `AliquotaIBS_Mun`: Alíquota Municipal (Ex: 2.00).

---

## 📚 2. Exemplos de Uso (Cenários Reais)

Aqui estão exemplos prontos para copiar e colar.

### Cenário 1: Venda Normal (Lucro Real/Presumido) - CST 00
Venda dentro do estado, tributada integralmente.

```pascal
var Calc: TCalculadoraFiscal;
begin
  Calc := TCalculadoraFiscal.Create;
  try
    // Dados do Item
    Calc.ValorProduto := 1000.00;
    
    // Configuração
    Calc.Regime := rtRegimeNormal;
    Calc.CST_CSOSN := '00';
    Calc.AliquotaICMS := 18.00;
    
    // PIS/COFINS
    Calc.CST_PIS := '01';
    Calc.AliquotaPIS := 1.65;
    Calc.CST_COFINS := '01';
    Calc.AliquotaCOFINS := 7.60;
    
    Calc.Calcular;
    
    // Resultados
    ShowMessage('ICMS: ' + CurrToStr(Calc.Resultado.vICMS)); // 180.00
    ShowMessage('PIS: ' + CurrToStr(Calc.Resultado.vPIS));   // 16.50
    ShowMessage('COFINS: ' + CurrToStr(Calc.Resultado.vCOFINS)); // 76.00
  finally
    Calc.Free;
  end;
end;
```

### Cenário 2: Venda com ST (Substituição Tributária) - CST 10
Venda para revendedor em outro estado (precisa ajustar MVA).

```pascal
var Calc: TCalculadoraFiscal;
begin
  Calc := TCalculadoraFiscal.Create;
  try
    Calc.ValorProduto := 1000.00;
    
    Calc.Regime := rtRegimeNormal;
    Calc.CST_CSOSN := '10'; // Tributada com ST
    
    // Parâmetros para ST Interestadual
    Calc.AliquotaICMS := 12.00;       // Interestadual (Origem)
    Calc.AliquotaInternaST := 18.00;  // Interna (Destino)
    Calc.MVAOriginal := 50.00;        // MVA Protocolo
    Calc.AutoAjustarMVA := True;      // <--- O Pulo do Gato: Ajusta MVA sozinho!
    
    Calc.Calcular;
    
    // A classe ajusta a MVA, calcula a base ST e desconta o ICMS próprio
    ShowMessage('MVA Ajustada usada: ' + FloatToStr(Calc.MVA) + '%');
    ShowMessage('Valor do ICMS ST a recolher: ' + CurrToStr(Calc.Resultado.vICMS_ST));
  finally
    Calc.Free;
  end;
end;
```

### Cenário 3: Simples Nacional (Crédito) - CSOSN 101
Empresa do Simples permitindo crédito de ICMS para o cliente.

```pascal
var Calc: TCalculadoraFiscal;
begin
  Calc := TCalculadoraFiscal.Create;
  try
    Calc.ValorProduto := 100.00;
    Calc.Regime := rtSimplesNacional;
    Calc.CST_CSOSN := '101';
    
    // Alíquota que consta na tabela do Simples para a faixa de faturamento
    Calc.AliquotaCreditoSN := 3.5; 
    
    Calc.Calcular;
    
    ShowMessage('Valor Crédito ICMS: ' + CurrToStr(Calc.Resultado.vCredICMSSN));
  finally
    Calc.Free;
  end;
end;
```

### Cenário 4: Reforma Tributária (IBS/CBS)
Calculando os novos impostos com detalhamento UF/Município.

```pascal
var Calc: TCalculadoraFiscal;
begin
  Calc := TCalculadoraFiscal.Create;
  try
    Calc.ValorProduto := 2000.00;
    
    // CSTs da Reforma (01 = Tributado)
    Calc.CST_CBS := '01';
    Calc.CST_IBS := '01';
    
    // Alíquotas
    Calc.AliquotaCBS := 0.90;      // Federal
    Calc.AliquotaIBS_UF := 10.00;  // Estadual
    Calc.AliquotaIBS_Mun := 2.00;  // Municipal
    
    Calc.Calcular;
    
    // Resultados Separados
    ShowMessage('CBS: ' + CurrToStr(Calc.Resultado.vCBS));
    ShowMessage('IBS Estado: ' + CurrToStr(Calc.Resultado.vIBS_UF));
    ShowMessage('IBS Município: ' + CurrToStr(Calc.Resultado.vIBS_Mun));
    ShowMessage('Total IBS: ' + CurrToStr(Calc.Resultado.vIBS));
  finally
    Calc.Free;
  end;
end;
```

---

## 🔌 Integração com ACBr (Exemplo Completo)

Como pegar os dados da calculadora e preencher o componente `ACBrNFe`.

```pascal
// Supondo 'Prod' como o item da nota no ACBr
with Prod.Imposto.ICMS do 
begin
  // CST e Origem você define baseada na regra de negócio
  CST := cst00; 
  orig := oeNacional;
  
  // Valores vêm da Calculadora
  modBC := dbiValorOperacao;
  vBC   := Calc.Resultado.vBC_ICMS;
  pICMS := Calc.Resultado.pICMS;
  vICMS := Calc.Resultado.vICMS;
  
  // Se fosse ST
  // vBCST := Calc.Resultado.vBC_ST;
  // vICMSST := Calc.Resultado.vICMS_ST;
  // pMVAST := Calc.Resultado.pMVA_ST;
end;
```

---

## 🧮 Métodos de Acesso Rápido (Calculadora de Bolso)

Se você não quer preencher tudo isso e só quer fazer uma conta rápida:

| Método | Exemplo de Uso |
| :--- | :--- |
| `CalcularValorImposto(Base, Aliq)` | `Calc.CalcularValorImposto(100, 18)` -> 18.00 |
| `CalcularBaseReduzida(Base, %Red)` | `Calc.CalcularBaseReduzida(100, 20)` -> 80.00 |
| `CalcularValorIBS_UF(Base, Aliq)` | `Calc.CalcularValorIBS_UF(1000, 17)` -> 170.00 |

---
> **Dúvidas?** Consulte o código fonte em `Unit_CalculoImpostos.pas`.
