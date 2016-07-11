USE [bodb02]
GO

/****** Object:  StoredProcedure [dbo].[Aff_User_DummyAccID]    Script Date: 10/17/2014 1:42:12 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

/****** Object:  Stored Procedure dbo.Aff_User_DummyAccID_xtest    Script Date: 12/13/2013 10:16:50 AM ******/
ALTER PROCEDURE [dbo].[Aff_BetList_SelDummyAccID] 
	@Username		VARCHAR(50)
	,@CustId		INT OUTPUT
	,@IBCUsername	VARCHAR(50) OUTPUT
	,@CurrencyId	INT OUTPUT
AS
/*
Created:20141017@Bobby.Nguyen
Task: Get Betlist Parlay by TransID
DB: DBEXT/bodb02
Orgiginal: DBEXT/bodb02.dbo.[Aff_User_DummyAccID]

Revisions:    
	- 20141017@Bobby.Nguyen: Initial SP
*/
BEGIN
	SET NOCOUNT ON;

	SELECT TOP 1 @CustId = CustId
		,@IBCUsername = username
		,@CurrencyId = currency
	FROM dbo.Customer WITH (NOLOCK)
	WHERE Username2 = @Username
END
GO

GRANT EXECUTE ON [dbo].[Aff_BetList_SelDummyAccID] TO [bodbAdminNet] AS [dbo]
GO

GRANT EXECUTE ON [dbo].[Aff_BetList_SelDummyAccID] TO [bodbDownlineNet] AS [dbo]
GO


