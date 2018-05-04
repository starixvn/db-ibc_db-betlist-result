/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet,bodbDownlineNet,bodbDownlineNetView" viewers="vnteam" isFunction="0" isNested="0"></info>*/
USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Acc_BetList_BetTrade_Detail]    Script Date: 8/4/2016 1:33:16 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Acc_BetList_Lucky3_Detail]
	@TransId	BIGINT,
	@CustId		INT
AS

/*
	Created: Kos@20170511
	Task: Get ticket detail of Lucky 3 ticket [#Redmine: 58978]
	DB: DBACC.bodb02
	Original:
	Revisions:

	Parameters:
		- @TransId: TransId of Lucky 3 ticket
		- @CustId: CustId of Lucky 3 ticket
*/

BEGIN
	SET NOCOUNT ON

	-- Create temp table
	DECLARE @Data TABLE (
		TransId		BIGINT,
		MatchId		INT,
		CustId		INT,
		BetType		SMALLINT,
		StatusId	TINYINT,
		TransDesc	NVARCHAR(1000),
		Hdp1		SMALLMONEY,
		Bets		SMALLMONEY,
		Hits		SMALLINT,
		Prize		TINYINT,
		PrizeAmount	MONEY,
		Stake		MONEY,
		WinLost		MONEY,
		PlayerComm	MONEY,
		SDiscount	SMALLMONEY,
		ADiscount	SMALLMONEY,
		Discount	SMALLMONEY,
		SComm		MONEY,
		AComm		MONEY,
		Comm		MONEY
	)

	-- Get ticket
	IF EXISTS ( SELECT 1 FROM dbo.BetLucky3Result WITH (NOLOCK) WHERE TransId = @TransId )
	BEGIN
		INSERT INTO @Data
		SELECT
			b.TransId,
			b.MatchId,
			b.CustId,
			b.BetType,
			b.StatusId,
			b.TransDesc,
			b.Hdp1,
			b.Odds AS Bets,
			b.Hits,
			b.Prize,
			b.PrizeAmount,
			b.Hdp1 * b.Odds * b.Hits AS Stake,
			(b.WinLost - b.Hdp1 * b.Odds * b.Hits) AS WinLost,
			b.PlayerComm,
			b.sDiscount,
			b.aDiscount,
			b.Discount,
			(b.sComm - b.aComm) AS SComm,
			(b.aComm - b.Comm) AS AComm,
			b.Comm
		FROM dbo.BetLucky3Result AS b WITH (NOLOCK)
		WHERE b.TransId = @TransId
			AND b.CustId = @CustId
			AND b.BetType IN (1601, 1602)
	END
	ELSE IF EXISTS ( SELECT 1 FROM dbo.BetLucky3Result14 WITH (NOLOCK) WHERE transid = @TransId )
	BEGIN
		INSERT INTO @Data
		SELECT
			b.TransId,
			b.MatchId,
			b.CustId,
			b.BetType,
			b.StatusId,
			b.TransDesc,
			b.Hdp1,
			b.Odds AS Bets,
			b.Hits,
			b.Prize,
			b.PrizeAmount,
			b.Hdp1 * b.Odds * b.Hits AS Stake,
			(b.WinLost - b.Hdp1 * b.Odds * b.Hits) AS WinLost,
			b.PlayerComm,
			b.sDiscount,
			b.aDiscount,
			b.Discount,
			(b.sComm - b.aComm) AS SComm,
			(b.aComm - b.Comm) AS AComm,
			b.Comm
		FROM dbo.BetLucky3Result14 AS b WITH (NOLOCK)
		WHERE b.TransId = @TransId
			AND b.CustId = @CustId
			AND b.BetType IN (1601, 1602)
	END
	ELSE IF EXISTS ( SELECT 1 FROM bodb_Archive.dbo.BetLucky3Result_bk WITH (NOLOCK) WHERE transid = @TransId )
	BEGIN
		INSERT INTO @Data
		SELECT
			b.TransId,
			b.MatchId,
			b.CustId,
			b.BetType,
			b.StatusId,
			b.TransDesc,
			b.Hdp1,
			b.Odds AS Bets,
			b.Hits,
			b.Prize,
			b.PrizeAmount,
			b.Hdp1 * b.Odds * b.Hits AS Stake,
			(b.WinLost - b.Hdp1 * b.Odds * b.Hits) AS WinLost,
			b.PlayerComm,
			b.sDiscount,
			b.aDiscount,
			b.Discount,
			(b.sComm - b.aComm) AS SComm,
			(b.aComm - b.Comm) AS AComm,
			b.Comm
		FROM bodb_Archive.dbo.BetLucky3Result_bk AS b WITH (NOLOCK)
		WHERE b.TransId = @TransId
			AND b.CustId = @CustId
			AND b.BetType IN (1601, 1602)
	END

	SELECT *,
		CASE StatusId
			WHEN 111 THEN 'Draw'
			WHEN 112 THEN 'Won'
			WHEN 113 THEN 'Lose'
			ELSE ''
		END AS Status
	FROM @Data
	ORDER BY BetType,
		StatusId,
		Prize,
		TransDesc
END



GO
GRANT	VIEW DEFINITION	ON	[Acc_BetList_Lucky3_Detail]	TO	vnteam
GRANT	EXECUTE	ON	[Acc_BetList_Lucky3_Detail]	TO	bodbExtAccNet
GRANT	EXECUTE	ON	[Acc_BetList_Lucky3_Detail]	TO	bodbDownlineNetView
GRANT	EXECUTE	ON	[Acc_BetList_Lucky3_Detail]	TO	bodbDownlineNet
GRANT	EXECUTE	ON	[Acc_BetList_Lucky3_Detail]	TO	bodbAdminNet
GO
