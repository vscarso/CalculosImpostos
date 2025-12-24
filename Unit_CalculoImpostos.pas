unit Unit_CalculoImpostos;

{
  --------------------------------------------------------------------------------
  Unit de Cálculo de Impostos - NF-e / NFC-e
  --------------------------------------------------------------------------------
  Autor: Vitor Scarso
  GitHub: github/vscarso
  Data: 24/12/2025
  Descrição:
    Classe responsável por centralizar toda a lógica de cálculo de tributos
    (ICMS, IPI, PIS, COFINS, ISSQN) e regras da Reforma Tributária (IBS, CBS, IS).
  --------------------------------------------------------------------------------
}

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math;

type
  // Enum para definir o Regime Tributário do Emitente
  TRegimeTributario = (rtSimplesNacional, rtRegimeNormal);

  // Enum para Origem da Mercadoria
  TOrigemMercadoria = (
    omNacional = 0,
    omEstrangeiraImportacaoDireta = 1,
    omEstrangeiraAdquiridaNoMercadoInterno = 2,
    omNacionalConteudoImportacaoSuperior40 = 3,
    omNacionalProducaoConformeProcessoBasico = 4,
    omNacionalConteudoImportacaoInferior40 = 5,
    omEstrangeiraImportacaoDiretaSemSimilar = 6,
    omEstrangeiraAdquiridaNoMercadoInternoSemSimilar = 7,
    omNacionalConteudoImportacaoSuperior70 = 8
  );

  { TResultadoImpostos
    Record para armazenar os resultados dos cálculos de forma estruturada.
    Isso facilita a atribuição em lote depois. }
  TResultadoImpostos = record
    // ICMS Próprio
    vBC_ICMS: Currency;
    pICMS: Double;
    vICMS: Currency;
    modBC: Integer; // 0=Margem Valor Agregado, 3=Valor Operação, etc.
    pRedBC: Double; // Percentual de Redução de Base

    // ICMS Diferido (CST 51)
    vICMSOp: Currency;    // Valor do ICMS da Operação
    pDif: Double;         // Percentual do Diferimento
    vICMSDif: Currency;   // Valor do ICMS Diferido

    // ICMS Desonerado
    vICMSDeson: Currency;
    motDesICMS: Integer;  // Motivo da desoneração

    // ICMS ST (Substituição Tributária)
    vBC_ST: Currency;
    pICMS_ST: Double;
    vICMS_ST: Currency;
    pMVA_ST: Double;
    pRedBC_ST: Double;

    // IPI
    vBC_IPI: Currency;
    pIPI: Double;
    vIPI: Currency;

    // PIS
    vBC_PIS: Currency;
    pPIS: Double;
    vPIS: Currency;

    // COFINS
    vBC_COFINS: Currency;
    pCOFINS: Double;
    vCOFINS: Currency;

    // DIFAL (Partilha ICMS Interestadual)
    vBC_UF_Dest: Currency;
    vBC_FCP_UF_Dest: Currency;
    pFCP_UF_Dest: Double;
    vFCP_UF_Dest: Currency;
    pICMS_UF_Dest: Double;
    pICMS_Inter: Double;
    pICMS_Partilha: Double;
    vICMS_UF_Dest: Currency;
    vICMS_UF_Remet: Currency;

    // Simples Nacional (Crédito)
    pCredSN: Double;
    vCredICMSSN: Currency;
    
    // FCP (Fundo de Combate à Pobreza)
    vBC_FCP: Currency;
    pFCP: Double;
    vFCP: Currency;
    vBC_FCPST: Currency;
    pFCPST: Double;
    vFCPST: Currency;

    // Reforma Tributária (IBS/CBS/IS)
    // IBS
    vBC_IBS: Currency;
    pIBS: Double;
    vIBS: Currency;
    
    // CBS
    vBC_CBS: Currency;
    pCBS: Double;
    vCBS: Currency;
    
    // Imposto Seletivo (IS)
    vBC_IS: Currency;
    pIS: Double;
    vIS: Currency;
  end;

  { TCalculadoraFiscal
    Classe responsável por orquestrar os cálculos tributários do item. }
  TCalculadoraFiscal = class
  private
    // Entradas
    FValorProduto: Currency;
    FQuantidade: Double;
    FValorFrete: Currency;
    FValorSeguro: Currency;
    FValorOutrasDespesas: Currency;
    FValorDesconto: Currency;

    // Configuração Fiscal
    FRegime: TRegimeTributario;
    FCST_CSOSN: String; // Ex: '00', '101', '500'
    FOrigem: TOrigemMercadoria;
    
    // Reforma Tributária: Novo Código de Tributação IBS/CBS
    // O padrão será usar CST específico ou lógica separada. A NT 2025.002 define novos CSTs.
    // Vamos assumir que o usuário passará as alíquotas do IBS/CBS.
    FAliquotaIBS: Double;
    FAliquotaCBS: Double;
    FAliquotaIS: Double; // Imposto Seletivo

    // Alíquotas e Reduções
    FAliquotaICMS: Double;
    FReducaoBaseICMS: Double; // Em % (ex: 33.33)
    FAliquotaDiferimento: Double; // Para CST 51 (ex: 100% ou 33.33%)
    FMotivoDesoneracao: Integer; // Para CST 20, 30, 40, etc.
    
    // DIFAL
    FAliquotaICMSInter: Double; // Interestadual (4, 7 ou 12)
    FAliquotaICMSIntra: Double; // Interna Destino (ex: 18)
    FAliquotaFCPDest: Double;   // FCP no Destino
    
    FAliquotaIPI: Double;
    
    FAliquotaPIS: Double;
    FAliquotaCOFINS: Double;
    
    // Variáveis para ST
    FMVA: Double; // Margem de Valor Agregado
    FAliquotaInternaST: Double; // Alíquota do destino
    FReducaoBaseST: Double;

    // Variáveis para Simples Nacional
    FAliquotaCreditoSN: Double; // Alíquota aplicável para crédito (CSOSN 101/201)

    // Variáveis para FCP
    FAliquotaFCP: Double;
    FAliquotaFCPST: Double;
    
    // CSTs Específicos (além do CST_CSOSN do ICMS)
    FCST_IPI: String;
    FCST_PIS: String;
    FCST_COFINS: String;
    
    // Valores Específicos por Unidade (Pauta)
    FValorUnidIPI: Currency;
    FValorUnidPIS: Currency;
    FValorUnidCOFINS: Currency;

    // Resultado
    FResultado: TResultadoImpostos;

    procedure ZerarResultado;
    function GetValorTotalItem: Currency; // Prod + Frete + Seg + Outras - Desc

    // Métodos internos de cálculo específicos
    procedure CalcularICMS_Normal;
    procedure CalcularICMS_ST;
    procedure CalcularICMS_Simples; // Para CSOSN
    procedure CalcularIPI;
    procedure CalcularPISCOFINS;
    procedure CalcularFCP;
    procedure CalcularDIFAL; // Novo método para Partilha
    procedure CalcularReformaTributaria; // Novo método para IBS/CBS/IS

  public
    constructor Create;

    // Método principal
    procedure Calcular;

    // Propriedades de Entrada
    property ValorProduto: Currency read FValorProduto write FValorProduto;
    property Quantidade: Double read FQuantidade write FQuantidade;
    property ValorFrete: Currency read FValorFrete write FValorFrete;
    property ValorSeguro: Currency read FValorSeguro write FValorSeguro;
    property ValorOutrasDespesas: Currency read FValorOutrasDespesas write FValorOutrasDespesas;
    property ValorDesconto: Currency read FValorDesconto write FValorDesconto;

    property Regime: TRegimeTributario read FRegime write FRegime;
    property CST_CSOSN: String read FCST_CSOSN write FCST_CSOSN;
    property Origem: TOrigemMercadoria read FOrigem write FOrigem;

    // Propriedades Reforma Tributária
    property AliquotaIBS: Double read FAliquotaIBS write FAliquotaIBS;
    property AliquotaCBS: Double read FAliquotaCBS write FAliquotaCBS;
    property AliquotaIS: Double read FAliquotaIS write FAliquotaIS;

    property AliquotaICMS: Double read FAliquotaICMS write FAliquotaICMS;
    property ReducaoBaseICMS: Double read FReducaoBaseICMS write FReducaoBaseICMS;
    property AliquotaDiferimento: Double read FAliquotaDiferimento write FAliquotaDiferimento;
    property MotivoDesoneracao: Integer read FMotivoDesoneracao write FMotivoDesoneracao;

    property AliquotaICMSInter: Double read FAliquotaICMSInter write FAliquotaICMSInter;
    property AliquotaICMSIntra: Double read FAliquotaICMSIntra write FAliquotaICMSIntra;
    property AliquotaFCPDest: Double read FAliquotaFCPDest write FAliquotaFCPDest;

    property AliquotaIPI: Double read FAliquotaIPI write FAliquotaIPI;
    property AliquotaPIS: Double read FAliquotaPIS write FAliquotaPIS;
    property AliquotaCOFINS: Double read FAliquotaCOFINS write FAliquotaCOFINS;

    property MVA: Double read FMVA write FMVA;
    property AliquotaInternaST: Double read FAliquotaInternaST write FAliquotaInternaST;
    property ReducaoBaseST: Double read FReducaoBaseST write FReducaoBaseST;

    property AliquotaCreditoSN: Double read FAliquotaCreditoSN write FAliquotaCreditoSN;
    
    property AliquotaFCP: Double read FAliquotaFCP write FAliquotaFCP;
    property AliquotaFCPST: Double read FAliquotaFCPST write FAliquotaFCPST;

    property CST_IPI: String read FCST_IPI write FCST_IPI;
    property CST_PIS: String read FCST_PIS write FCST_PIS;
    property CST_COFINS: String read FCST_COFINS write FCST_COFINS;

    property ValorUnidIPI: Currency read FValorUnidIPI write FValorUnidIPI;
    property ValorUnidPIS: Currency read FValorUnidPIS write FValorUnidPIS;
    property ValorUnidCOFINS: Currency read FValorUnidCOFINS write FValorUnidCOFINS;

    // Acesso ao Resultado
    property Resultado: TResultadoImpostos read FResultado;
  end;

implementation

{ TCalculadoraFiscal }

constructor TCalculadoraFiscal.Create;
begin
  ZerarResultado;
  FRegime := rtRegimeNormal;
  FOrigem := omNacional;
  FQuantidade := 1;
end;

procedure TCalculadoraFiscal.ZerarResultado;
begin
  FillChar(FResultado, SizeOf(FResultado), 0);
  // Define padrões
  FResultado.modBC := 3; // 3 = Valor da Operação (padrão mais comum)
end;

function TCalculadoraFiscal.GetValorTotalItem: Currency;
begin
  // Base padrão: Valor do Produto + Despesas Acessórias - Desconto Incondicional
  Result := (FValorProduto + FValorFrete + FValorSeguro + FValorOutrasDespesas) - FValorDesconto;
  if Result < 0 then Result := 0;
end;

procedure TCalculadoraFiscal.CalcularICMS_Normal;
var
  BaseCalc, BaseIntegral, ValorICMSIntegral: Currency;
begin
  BaseIntegral := GetValorTotalItem;
  BaseCalc := BaseIntegral;

  // Aplica Redução de Base de Cálculo se houver
  if FReducaoBaseICMS > 0 then
    BaseCalc := BaseCalc * (1 - (FReducaoBaseICMS / 100));

  FResultado.vBC_ICMS := BaseCalc;
  FResultado.pICMS := FAliquotaICMS;
  FResultado.vICMS := RoundTo(BaseCalc * (FAliquotaICMS / 100), -2);
  
  // Cálculo de Desoneração (ICMS que deixou de ser pago devido à redução)
  if (FReducaoBaseICMS > 0) and (FMotivoDesoneracao > 0) then
  begin
    ValorICMSIntegral := RoundTo(BaseIntegral * (FAliquotaICMS / 100), -2);
    FResultado.vICMSDeson := ValorICMSIntegral - FResultado.vICMS;
    FResultado.motDesICMS := FMotivoDesoneracao;
  end;
  
  // Cálculo de Diferimento (CST 51)
  if (FCST_CSOSN = '51') then
  begin
    FResultado.vICMSOp := FResultado.vICMS; // Valor da operação antes do diferimento
    FResultado.pDif := FAliquotaDiferimento;
    
    if FAliquotaDiferimento > 0 then
    begin
      FResultado.vICMSDif := RoundTo(FResultado.vICMSOp * (FAliquotaDiferimento / 100), -2);
      FResultado.vICMS := FResultado.vICMSOp - FResultado.vICMSDif; // Valor devido é o que sobra
    end;
  end;
end;

procedure TCalculadoraFiscal.CalcularDIFAL;
var
  BaseDIFAL, DifAliquota: Double;
begin
  BaseDIFAL := GetValorTotalItem;
  
  // DIFAL = Base * (AlqIntra - AlqInter)
  // Assumindo partilha 100% destino (padrão atual)
  
  if FAliquotaICMSIntra > FAliquotaICMSInter then
  begin
    DifAliquota := FAliquotaICMSIntra - FAliquotaICMSInter;
    
    FResultado.vBC_UF_Dest := BaseDIFAL;
    FResultado.pICMS_UF_Dest := FAliquotaICMSIntra;
    FResultado.pICMS_Inter := FAliquotaICMSInter;
    FResultado.pICMS_Partilha := 100; // 100% para destino
    
    FResultado.vICMS_UF_Dest := RoundTo(BaseDIFAL * (DifAliquota / 100), -2);
    FResultado.vICMS_UF_Remet := 0; // Sem partilha para remetente atualmente
  end;
  
  // FCP Destino
  if FAliquotaFCPDest > 0 then
  begin
    FResultado.vBC_FCP_UF_Dest := BaseDIFAL;
    FResultado.pFCP_UF_Dest := FAliquotaFCPDest;
    FResultado.vFCP_UF_Dest := RoundTo(BaseDIFAL * (FAliquotaFCPDest / 100), -2);
  end;
end;

procedure TCalculadoraFiscal.CalcularICMS_ST;
var
  BaseST: Currency;
  ValorICMSProprio: Currency;
begin
  // 1. Calcula o ICMS Próprio (usado para abater no ST)
  // Nota: Mesmo que o emitente seja Simples Nacional, para fins de cálculo de ST, 
  // muitas vezes usa-se a regra geral ou alíquotas interestaduais. 
  // Aqui assumimos a lógica padrão de débito/crédito.
  
  ValorICMSProprio := FResultado.vICMS; // Assume que CalcularICMS_Normal já rodou ou simula-se
  if (FRegime = rtSimplesNacional) and (ValorICMSProprio = 0) then
  begin
     // Se for simples, usa-se a alíquota interestadual para achar o "ICMS Próprio virtual" para abatimento
     // Isso depende da legislação estadual, mas é comum usar a alíquota cheia (ex: 12% ou 7%) apenas para dedução.
     // VOU USAR A ALIQUOTA INFORMADA NO CAMPO ICMS COMO SENDO A INTERESTADUAL
     ValorICMSProprio := GetValorTotalItem * (FAliquotaICMS / 100); 
  end;

  // 2. Base do ST = (ValorItem + IPI se incidir na base) * (1 + MVA)
  // *Nota: IPI compõe a base do ICMS ST se o produto for para consumo final ou se não for contribuinte.
  // Para simplificar, vamos usar a base padrão.
  
  BaseST := GetValorTotalItem + FResultado.vIPI; // Soma IPI na base do ST geralmente
  
  // Aplica MVA
  if FMVA > 0 then
    BaseST := BaseST * (1 + (FMVA / 100));
    
  // Aplica Redução na Base ST
  if FReducaoBaseST > 0 then
    BaseST := BaseST * (1 - (FReducaoBaseST / 100));

  FResultado.vBC_ST := BaseST;
  FResultado.pICMS_ST := FAliquotaInternaST;
  FResultado.pMVA_ST := FMVA;
  FResultado.pRedBC_ST := FReducaoBaseST;
  
  // Valor ST = (BaseST * AliquotaInterna) - ICMSProprio
  FResultado.vICMS_ST := RoundTo((BaseST * (FAliquotaInternaST / 100)) - ValorICMSProprio, -2);
  
  if FResultado.vICMS_ST < 0 then FResultado.vICMS_ST := 0;
end;

procedure TCalculadoraFiscal.CalcularICMS_Simples;
begin
  // CSOSN 101 - Tributada com permissão de crédito
  if (FCST_CSOSN = '101') or (FCST_CSOSN = '201') then
  begin
    FResultado.pCredSN := FAliquotaCreditoSN;
    FResultado.vCredICMSSN := RoundTo(GetValorTotalItem * (FAliquotaCreditoSN / 100), -2);
  end;

  // CSOSN 201, 202, 203, 900 - Pode ter ST
  if (FCST_CSOSN = '201') or (FCST_CSOSN = '202') or (FCST_CSOSN = '203') or (FCST_CSOSN = '900') then
  begin
    CalcularICMS_ST;
  end;
  
  // CSOSN 900 - Outros (Pode ter ICMS Próprio também)
  if FCST_CSOSN = '900' then
  begin
    CalcularICMS_Normal;
  end;
end;

procedure TCalculadoraFiscal.CalcularIPI;
var
  BaseIPI: Currency;
begin
  // Se CST não foi informado, mas tem alíquota, assume tributado (comportamento legado)
  if (FCST_IPI = '') and (FAliquotaIPI > 0) then FCST_IPI := '50';

  // CSTs de Saída Tributada: 50, 49, 99
  // CSTs de Entrada Tributada: 00, 49, 99
  if (FCST_IPI = '00') or (FCST_IPI = '49') or (FCST_IPI = '50') or (FCST_IPI = '99') then
  begin
    // Cálculo por Alíquota (Ad Valorem)
    if FAliquotaIPI > 0 then
    begin
      BaseIPI := GetValorTotalItem; // Geralmente Frete e Seguro entram na base do IPI
      FResultado.vBC_IPI := BaseIPI;
      FResultado.pIPI := FAliquotaIPI;
      FResultado.vIPI := RoundTo(BaseIPI * (FAliquotaIPI / 100), -2);
    end
    // Cálculo por Unidade (Pauta)
    else if FValorUnidIPI > 0 then
    begin
      FResultado.vBC_IPI := FQuantidade; // Base é a quantidade
      FResultado.vIPI := RoundTo(FQuantidade * FValorUnidIPI, -2);
      // pIPI fica zerado pois é valor fixo
    end;
  end
  else
  begin
    // Isento, Imune, Suspenso (01..05, 51..55)
    FResultado.vBC_IPI := 0;
    FResultado.pIPI := 0;
    FResultado.vIPI := 0;
  end;
end;

procedure TCalculadoraFiscal.CalcularPISCOFINS;
var
  BasePISCOFINS: Currency;
begin
  BasePISCOFINS := GetValorTotalItem;
  // *Importante: ICMS pode ser excluído da base do PIS/COFINS dependendo da decisão do STF ("Tese do Século")
  // Aqui faremos o cálculo padrão (Base Cheia), mas poderia haver uma flag para excluir o ICMS.

  // --- PIS ---
  // CSTs Tributáveis: 01, 02
  if (FCST_PIS = '01') or (FCST_PIS = '02') then
  begin
    FResultado.vBC_PIS := BasePISCOFINS;
    FResultado.pPIS := FAliquotaPIS;
    FResultado.vPIS := RoundTo(BasePISCOFINS * (FAliquotaPIS / 100), -2);
  end
  // CST Quantidade: 03
  else if (FCST_PIS = '03') then
  begin
    FResultado.vBC_PIS := FQuantidade;
    FResultado.vPIS := RoundTo(FQuantidade * FValorUnidPIS, -2);
  end
  // Outras Operações (pode ser tributado): 49..99
  else if (StrToIntDef(FCST_PIS, 0) >= 49) and (FAliquotaPIS > 0) then
  begin
    FResultado.vBC_PIS := BasePISCOFINS;
    FResultado.pPIS := FAliquotaPIS;
    FResultado.vPIS := RoundTo(BasePISCOFINS * (FAliquotaPIS / 100), -2);
  end
  else
  begin
    // Isento/Alíquota Zero (04, 05, 06, 07, 08, 09)
    FResultado.vBC_PIS := 0;
    FResultado.pPIS := 0;
    FResultado.vPIS := 0;
  end;

  // --- COFINS ---
  // CSTs Tributáveis: 01, 02
  if (FCST_COFINS = '01') or (FCST_COFINS = '02') then
  begin
    FResultado.vBC_COFINS := BasePISCOFINS;
    FResultado.pCOFINS := FAliquotaCOFINS;
    FResultado.vCOFINS := RoundTo(BasePISCOFINS * (FAliquotaCOFINS / 100), -2);
  end
  // CST Quantidade: 03
  else if (FCST_COFINS = '03') then
  begin
    FResultado.vBC_COFINS := FQuantidade;
    FResultado.vCOFINS := RoundTo(FQuantidade * FValorUnidCOFINS, -2);
  end
  // Outras Operações: 49..99
  else if (StrToIntDef(FCST_COFINS, 0) >= 49) and (FAliquotaCOFINS > 0) then
  begin
    FResultado.vBC_COFINS := BasePISCOFINS;
    FResultado.pCOFINS := FAliquotaCOFINS;
    FResultado.vCOFINS := RoundTo(BasePISCOFINS * (FAliquotaCOFINS / 100), -2);
  end
  else
  begin
    // Isento/Alíquota Zero
    FResultado.vBC_COFINS := 0;
    FResultado.pCOFINS := 0;
    FResultado.vCOFINS := 0;
  end;
end;

procedure TCalculadoraFiscal.CalcularFCP;
begin
  // FCP Normal
  if FAliquotaFCP > 0 then
  begin
    FResultado.vBC_FCP := FResultado.vBC_ICMS; // Geralmente segue a base do ICMS
    FResultado.pFCP := FAliquotaFCP;
    FResultado.vFCP := RoundTo(FResultado.vBC_FCP * (FAliquotaFCP / 100), -2);
  end;

  // FCP ST
  if FAliquotaFCPST > 0 then
  begin
    FResultado.vBC_FCPST := FResultado.vBC_ST;
    FResultado.pFCPST := FAliquotaFCPST;
    FResultado.vFCPST := RoundTo(FResultado.vBC_FCPST * (FAliquotaFCPST / 100), -2);
  end;
end;

procedure TCalculadoraFiscal.CalcularReformaTributaria;
var
  BaseCalculo: Currency;
begin
  // Base de Cálculo Geral: Valor do Item + Despesas Acessórias - Descontos
  // IMPORTANTE: IBS e CBS incidem sobre o valor da operação "por fora", mas para fins
  // de preenchimento inicial nos documentos fiscais, a base geralmente segue o valor da operação.
  // O IBS e CBS NÃO integram a sua própria base de cálculo (cálculo "por fora").
  
  BaseCalculo := GetValorTotalItem;

  // Cálculo IBS (Imposto sobre Bens e Serviços)
  if FAliquotaIBS > 0 then
  begin
    FResultado.vBC_IBS := BaseCalculo;
    FResultado.pIBS := FAliquotaIBS;
    FResultado.vIBS := RoundTo(BaseCalculo * (FAliquotaIBS / 100), -2);
  end;

  // Cálculo CBS (Contribuição sobre Bens e Serviços)
  if FAliquotaCBS > 0 then
  begin
    FResultado.vBC_CBS := BaseCalculo;
    FResultado.pCBS := FAliquotaCBS;
    FResultado.vCBS := RoundTo(BaseCalculo * (FAliquotaCBS / 100), -2);
  end;

  // Cálculo IS (Imposto Seletivo) - Incide sobre produtos prejudiciais à saúde/meio ambiente
  // A base do IS também é o valor da operação, mas o IS integra a base do ICMS/ISS e do próprio IBS/CBS?
  // Pela regra geral da reforma, o IS compõe a base de cálculo do ICMS, ISS, IBS e CBS.
  // No entanto, para simplificação inicial neste método, usaremos a base do item.
  // Caso o IS deva compor a base dos outros, a ordem de chamada dos métodos deve ser ajustada.
  if FAliquotaIS > 0 then
  begin
    FResultado.vBC_IS := BaseCalculo;
    FResultado.pIS := FAliquotaIS;
    FResultado.vIS := RoundTo(BaseCalculo * (FAliquotaIS / 100), -2);
  end;
end;

procedure TCalculadoraFiscal.Calcular;
begin
  ZerarResultado;

  // 1. Reforma Tributária (IBS/CBS/IS)
  // Calculamos primeiro pois o IS pode vir a compor a base de outros tributos no futuro.
  CalcularReformaTributaria;

  // 2. Calcula IPI (pois pode compor base de outros impostos)
  // Agora considera CSTs específicos
  CalcularIPI;

  // 3. Calcula ICMS baseado no Regime e CST/CSOSN
  if FRegime = rtRegimeNormal then
  begin
    // CSTs do Regime Normal
    // 00 - Tributada integralmente
    // 20 - Com redução de base
    // 10, 30, 70 - Com ST
    // 40, 41, 50 - Isenta/Não tributada
    // 51 - Diferimento
    // 90 - Outros
    
    if (FCST_CSOSN = '00') or (FCST_CSOSN = '20') or (FCST_CSOSN = '90') or (FCST_CSOSN = '10') or (FCST_CSOSN = '70') or (FCST_CSOSN = '51') then
      CalcularICMS_Normal;
      
    if (FCST_CSOSN = '10') or (FCST_CSOSN = '30') or (FCST_CSOSN = '70') or (FCST_CSOSN = '90') or (FCST_CSOSN = '201') or (FCST_CSOSN = '202') or (FCST_CSOSN = '203') then
      CalcularICMS_ST;
  end
  else // Simples Nacional
  begin
    CalcularICMS_Simples;
  end;

  // 3. Calcula PIS e COFINS
  // Verifica CST de PIS/COFINS dentro do método
  CalcularPISCOFINS;

  // 4. Calcula FCP
  CalcularFCP;
  
  // 5. Calcula DIFAL (Se houver alíquotas configuradas)
  if (FAliquotaICMSIntra > 0) and (FAliquotaICMSInter > 0) then
    CalcularDIFAL;
end;

end.
