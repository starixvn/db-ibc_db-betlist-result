USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Aff_User_BetListParlay]    Script Date: 10/17/2014 12:43:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE  [dbo].[Aff_BetList_SelBalanceUpDay]		
AS	
/*
Created:20141017@Bobby.Nguyen
Task: Get Balanceup Date for affiliate member betlist
DB: DBEXT/bodb02
Orgiginal: 

Revisions:    
	- 20141017@Bobby.Nguyen: Initial SP
*/ 
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @BalanceUpDay 	DATETIME
		, @MoveBetsDay 		DATETIME
	
	SELECT TOP 1 @BalanceUpDay = winlostdate
	FROM dbo.Bettrans WITH (NOLOCK)
	WHERE bettype = 20000 
		AND matchid = 0	AND custid = 3
	
	SELECT @MoveBetsDay = MAX(eventdate)  
	FROM dbo.match14 WITH(NOLOCK)  

	SELECT @BalanceUpDay as BalanceUpDay
		, @MoveBetsDay as MoveBetsDay
END
GO
GRANT EXECUTE ON [dbo].[Aff_BetList_SelBalanceUpDay] TO [bodbAdminNet] AS [dbo]
GO

GRANT EXECUTE ON [dbo].[Aff_BetList_SelBalanceUpDay] TO [bodbDownlineNet] AS [dbo]
GO