USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Lrf_BetList_RNG_Detail]    Script Date: 10/12/2015 11:00:26 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Acc_BetList_RNG_Detail]
	@RefNo		BIGINT,
	@CustId		INT,
	@TransType	TINYINT	= 0,
	@PageIndex	INT		= 1,
	@PageSize	INT		= 1000,
	@TotalRows	INT		= 0		OUTPUT
AS

/*
	Created: Kos@20151012
	Task : Get ticket detail from table betransRnG (Microgaming RNG Game)
	DB: DBAGE.bodb02
	Original:
	Revisions:
		- 20151030@Kos: Change ProductId/SportType of Microgaming RNG Casino
		- 20151229@Kos: Support RNG Casino Single Wallet and use SportBettypeMatrix [Redmine: #48958]
		- 20160304@Kos: Add MatchCode column
		- 20160331@Kos: Support Voidbridge [#Redmine: 54925]
		- 20160426@Kos: Support paging

	Parameters:
		- @TransType
			+ 0 : All (DRAW/WON/LOSE/Reject/Void/Refund/Running/Waiting)
			+ 1 : DRAW/WON/LOSE/Refund
			+ 2 : Reject/Void
			+ 3 : Running/Waiting
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @SportBettype TABLE(ProductID TINYINT, Bettype SMALLINT, EventType TINYINT, SubProduct VARCHAR(500))

	INSERT INTO @SportBettype
	EXEC bodb02.dbo.Acc_SportBettypeMatrix_Sel @mode = 5

	DELETE FROM @SportBettype
	WHERE ProductID NOT IN (6, 17, 22)	-- Support Microgaming RNG Casino, RNG Casino Single Wallet, Voidbridge
		OR (ProductID = 6 AND SubProduct = '')

	DECLARE @tmpStatus TABLE (statusId TINYINT)

	IF @TransType = 0
	BEGIN
		INSERT INTO @tmpStatus
		SELECT 111 UNION ALL
		SELECT 112 UNION ALL
		SELECT 113 UNION ALL
		SELECT 101 UNION ALL
		SELECT 102 UNION ALL
		SELECT 103 UNION ALL
		SELECT 0 UNION ALL
		SELECT 1
	END
	ELSE IF @TransType = 1
	BEGIN
		INSERT INTO @tmpStatus
		SELECT 111 UNION ALL
		SELECT 112 UNION ALL
		SELECT 113 UNION ALL
		SELECT 103
	END
	ELSE IF @TransType = 2
	BEGIN
		INSERT INTO @tmpStatus
		SELECT 101 UNION ALL
		SELECT 102
	END 
	ELSE IF @TransType = 3
	BEGIN
		INSERT INTO @tmpStatus(statusId)
		SELECT 0 UNION ALL
		SELECT 1
	END

	-- Create temp table
	CREATE TABLE #Data (
		TransId			BIGINT,
		SportType		INT,
		BetType			INT,
		TransDate		DATETIME,
		WinLostDate		DATETIME,
		Status			NVARCHAR(10),
		StatusId		TINYINT,
		Odds			MONEY,
		Stake			MONEY,
		Actual_Stake	MONEY,
		WinLost			MONEY,
		Commission		MONEY,
		SPositionTaking SMALLMONEY,
		MPositionTaking SMALLMONEY,
		APositionTaking SMALLMONEY,
		SWinLost		MONEY,
		MWinLost		MONEY,
		AWinLost		MONEY,
		SDiscount		DECIMAL(9, 8),
		ADiscount		DECIMAL(9, 8),
		Discount		DECIMAL(9, 8),
		SComm			MONEY,
		AComm			MONEY,
		Comm			MONEY,
		Ip				NVARCHAR(15),
		TransDesc		NVARCHAR(300),
		BetCheck		NVARCHAR(50),
		MatchCode		VARCHAR(50)
	)

	-- Get ticket
	IF EXISTS ( SELECT 1 FROM dbo.bettrans WITH (NOLOCK) WHERE transid = @RefNo )
	BEGIN
		INSERT INTO #Data
		SELECT
			brng.transid,
			brng.productID AS SportType,
			brng.gameID AS BetType,
			brng.transdate,
			brng.winlostdate,
			brng.status,
			brng.statusID,
			brng.odds,
			brng.stake,
			brng.actual_stake,
			(brng.winlost - brng.actual_stake) AS WinLost,
			brng.playercomm AS commission,
			brng.spositiontaking,
			brng.mpositiontaking,
			brng.apositiontaking,
			brng.swinlost,
			brng.mwinlost,
			brng.awinlost,
			brng.sdiscount,
			brng.adiscount,
			brng.discount,
			(brng.scomm - brng.acomm) AS scomm,
			(brng.acomm - brng.comm) AS acomm,
			(brng.comm - brng.playercomm) AS comm,
			brng.ip,
			brng.transdesc,
			CASE
				WHEN sbt.productID IN (6, 17, 22) THEN brng.TranId3rd
				ELSE ''
			END AS BetCheck,
			'' AS MatchCode
		FROM dbo.bettransRnG AS brng WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON brng.gameID = sbt.Bettype
		WHERE brng.custid = @CustId 
			AND brng.RefNo = @RefNo
			AND brng.statusID IN (SELECT statusId FROM @tmpStatus)
	END
	ELSE IF EXISTS ( SELECT 1 FROM dbo.bettrans14 WITH (NOLOCK) WHERE transid = @RefNo )
	BEGIN
		INSERT INTO #Data
		SELECT
			brng.transid,
			brng.productID AS SportType,
			brng.gameID AS BetType,
			brng.transdate,
			brng.winlostdate,
			brng.status,
			brng.statusID,
			brng.odds,
			brng.stake,
			brng.actual_stake,
			(brng.winlost - brng.actual_stake) AS WinLost,
			brng.playercomm AS commission,
			brng.spositiontaking,
			brng.mpositiontaking,
			brng.apositiontaking,
			brng.swinlost,
			brng.mwinlost,
			brng.awinlost,
			brng.sdiscount,
			brng.adiscount,
			brng.discount,
			(brng.scomm - brng.acomm) AS scomm,
			(brng.acomm - brng.comm) AS acomm,
			(brng.comm - brng.playercomm) AS comm,
			brng.ip,
			brng.transdesc,
			CASE
				WHEN sbt.productID IN (6, 17, 22) THEN brng.TranId3rd
				ELSE ''
			END AS BetCheck,
			'' AS MatchCode
		FROM dbo.bettransRnG14 AS brng WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON brng.gameID = sbt.Bettype
		WHERE brng.custid = @CustId AND brng.RefNo = @RefNo
	END
	ELSE IF EXISTS ( SELECT 1 FROM DBARC.bodb_Archive.dbo.bettrans_bk WITH (NOLOCK) WHERE transid = @RefNo )
	BEGIN
		INSERT INTO #Data
		SELECT
			brng.transid,
			brng.productID AS SportType,
			brng.gameID AS BetType,
			brng.transdate,
			brng.winlostdate,
			brng.status,
			brng.statusID,
			brng.odds,
			brng.stake,
			brng.actual_stake,
			(brng.winlost - brng.actual_stake) AS WinLost,
			brng.playercomm AS commission,
			brng.spositiontaking,
			brng.mpositiontaking,
			brng.apositiontaking,
			brng.swinlost,
			brng.mwinlost,
			brng.awinlost,
			brng.sdiscount,
			brng.adiscount,
			brng.discount,
			(brng.scomm - brng.acomm) AS scomm,
			(brng.acomm - brng.comm) AS acomm,
			(brng.comm - brng.playercomm) AS comm,
			brng.ip,
			brng.transdesc,
			CASE
				WHEN sbt.productID IN (6, 17, 22) THEN brng.TranId3rd
				ELSE ''
			END AS BetCheck,
			'' AS MatchCode
		FROM DBARC.bodb_Archive.dbo.bettransRnG_bk AS brng WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON brng.gameID = sbt.Bettype
		WHERE brng.custid = @CustId AND brng.RefNo = @RefNo
	END

	-- Paging
	SELECT @TotalRows = COUNT(1)
	FROM #Data

	SELECT *
	FROM (
		SELECT ROW_NUMBER() OVER(ORDER BY TransId) AS RowNum, *
		FROM #Data ) AS t
	WHERE t.RowNum BETWEEN ((@PageIndex - 1) * @PageSize + 1) AND (@PageSize * @PageIndex)
	ORDER BY t.TransId

	DROP TABLE #Data
END



GRANT	VIEW DEFINITION	ON	Acc_BetList_RNG_Detail	TO	vnteam
GRANT	EXECUTE	ON	Acc_BetList_RNG_Detail	TO	bodbExtAccNet
GRANT	EXECUTE	ON	Acc_BetList_RNG_Detail	TO	bodbDownlineNetView
GRANT	EXECUTE	ON	Acc_BetList_RNG_Detail	TO	bodbDownlineNet
GRANT	EXECUTE	ON	Acc_BetList_RNG_Detail	TO	bodbAdminNet