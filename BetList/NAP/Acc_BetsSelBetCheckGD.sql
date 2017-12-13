USE BODB02
GO

ALTER PROCEDURE [dbo].[Acc_BetsSelBetCheckGD]
	@refno		BIGINT,
	@Language	NVARCHAR(2) = 'E'
AS

/*
	Created by: [Tom]
	Date: 20150508
	Task: Get info of Gold Deluxe Bets 
	DB: DBAGE.BODB02
	Original:

	Revisions:
		- 20151210@Kos: Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @BetListGD TABLE (
		TransID			BIGINT
		,Bettype		INT
		,oddsid			INT
		,odds			MONEY
		,betteam		NVARCHAR(50)
		,statusid		INT
		,TransDesc		VARCHAR(300)
		,WinlostDate	SMALLDATETIME	
	)

	IF EXISTS ( SELECT TOP 1 1 FROM dbo.bettransg WITH (NOLOCK) WHERE refno = @refno )
	BEGIN
		INSERT INTO @BetListGD(TransID, Bettype, oddsid, odds, betteam, statusid, TransDesc, WinlostDate)
		SELECT btg.TransID
			,btg.Bettype
			,btg.oddsid
			,btg.odds
			,btg.betteam
			,btg.statusid
			,btg.TransDesc
			,WinlostDate
		FROM dbo.bettransg AS btg WITH (NOLOCK)
		WHERE refno = @refno
	END
	ELSE IF EXISTS ( SELECT TOP 1 1 FROM dbo.bettransg14 WITH (NOLOCK) WHERE refno = @refno )
	BEGIN
		INSERT INTO @BetListGD(TransID, Bettype, oddsid, odds, betteam, statusid, TransDesc, WinlostDate)
		SELECT btg.TransID
			,btg.Bettype
			,btg.oddsid
			,btg.odds
			,btg.betteam
			,btg.statusid
			,btg.TransDesc
			,WinlostDate
		FROM dbo.bettransg14 AS btg WITH (NOLOCK)
		WHERE refno = @refno
	END
	ELSE IF EXISTS ( SELECT TOP 1 1 FROM DBARC.bodb_archive.dbo.bettransg WITH (NOLOCK) WHERE refno = @refno )
	BEGIN
		INSERT INTO @BetListGD(TransID, Bettype, oddsid, odds, betteam, statusid, TransDesc, WinlostDate)
		SELECT btg.TransID
			,btg.Bettype
			,btg.oddsid
			,btg.odds
			,btg.betteam
			,btg.statusid
			,btg.TransDesc
			,WinlostDate
		FROM DBARC.bodb_archive.dbo.bettransg AS btg WITH (NOLOCK)
		WHERE refno = @refno
	END

	SELECT TransID
		,Bettype
		,oddsid
		,odds
		,betteam
		,statusid
		,TransDesc
		,WinlostDate
	FROM @BetListGD
	ORDER BY TransID DESC
END


GO
GRANT EXECUTE ON [dbo].[Acc_BetsSelBetCheckGD] TO [bodbAdminNet]
GO
GRANT EXECUTE ON [dbo].[Acc_BetsSelBetCheckGD] TO [bodbExtAccNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_BetsSelBetCheckGD] TO [vnteam]
GO
