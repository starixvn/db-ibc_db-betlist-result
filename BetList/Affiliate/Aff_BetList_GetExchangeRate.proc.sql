ALTER PROCEDURE [dbo].[Aff_BetList_GetExchangeRate]    
	@FromCurrency smallint,    
	@ToCurrency smallint,  
	@Date smalldatetime = null,  
	@Rate FLOAT = 0 OUTPUT  
AS    
/*
Created:20141017@Bobby.Nguyen
Task: Get ExRate for member betlist
DB: DBAFF/Affiliate_Athena000
Orgiginal: 

Revisions:    
	- 20141017@Bobby.Nguyen: Initial SP
*/     
BEGIN    
	SET NOCOUNT ON;
	SELECT @Rate = dbo.Aff_GetExchangeRate(@FromCurrency, @ToCurrency, @Date)  
END  
GO
GRANT EXECUTE ON [dbo].[Aff_BetList_GetExchangeRate] TO [bodbAdminNet] AS [dbo]
GO

GRANT EXECUTE ON [dbo].[Aff_BetList_GetExchangeRate] TO [bodbDownlineNet] AS [dbo]
GO