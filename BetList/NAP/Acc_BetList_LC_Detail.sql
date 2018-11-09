/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet,bodbDownlineNet,bodbDownlineNetView" viewers="vnteam" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Acc_BetList_LC_Detail]
	@RefNo		BIGINT,
	@CustId		INT,
	@TransType	TINYINT	= 0,
	@PageIndex	INT		= 1,
	@PageSize	INT		= 1000,
	@TotalRows	INT		= 0		OUTPUT
AS

/*
	Created: Kos@20151012
	Task : Get ticket detail from table betransLC (AG Casino)
	DB: DBACC.bodb02
	Original:
	Revisions:
		- 20151012@Kos: Support AG Casino Single Wallet
		- 20160215@Kos: Support AllBet [#Redmine: 50864]
		- 20160309@Kos: Support paging
		- 20160704@Kos: Include Void/Rejected detail ticket in TransType = 1 [Redmine: #59366]
		- 20161111@Kos: Return currency name
		- 20180328@Kos: Increase Transdesc length to 1000 [Redmine: #92841]
		- 20181109@Kos: Move from DBAGE to DBACC [#Redmine: 104521]

	Parameters:
		- @TransType
			+ 0 : All (DRAW/WON/LOSE/Reject/Void/Refund/Running/Waiting)
			+ 1 : DRAW/WON/LOSE/Refund
			+ 2 : Reject/Void
			+ 3 : Running/Waiting
*/

BEGIN
	SET NOCOUNT ON

	-- Get Sport Bettype Matrix --
	DECLARE @SportBettype TABLE (ProductID TINYINT, BetType SMALLINT, EventType TINYINT)

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype
	SELECT ProductID, BetType, EventType
	FROM bodb02.dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
	WHERE ProductID IN (11, 21)	-- Support AG Casino, AllBet only

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
		SELECT 103 UNION ALL
		SELECT 101 UNION ALL
		SELECT 102
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
		Currency		NVARCHAR(50),
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
		TransDesc		NVARCHAR(1000),
		BetCheck		NVARCHAR(50),
		MatchCode		VARCHAR(50)
	)

	-- Get currency name
	DECLARE @CurrencyName	NVARCHAR(50),
		@WhTicket			TINYINT

	SELECT @CurrencyName = ex.currency,
		@WhTicket = 1
	FROM dbo.bettrans AS b WITH (NOLOCK)
		INNER JOIN dbo.Exchange AS ex WITH (NOLOCK) ON b.currency = ex.exchangeid
	WHERE b.transid = @RefNo

	IF @CurrencyName IS NULL
	BEGIN
		SELECT @CurrencyName = ex.currency,
			@WhTicket = 2
		FROM dbo.bettrans14 AS b WITH (NOLOCK)
			INNER JOIN dbo.Exchange AS ex WITH (NOLOCK) ON b.currency = ex.exchangeid
		WHERE b.transid = @RefNo

		IF @CurrencyName IS NULL
		BEGIN
			SELECT @CurrencyName = ex.currency,
				@WhTicket = 3
			FROM bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK)
				INNER JOIN dbo.Exchange AS ex WITH (NOLOCK) ON b.currency = ex.exchangeid
			WHERE b.transid = @RefNo
		END
	END

	-- Get ticket
	IF @WhTicket = 1
	BEGIN
		INSERT INTO #Data
		SELECT
			blc.transid,
			blc.productID AS SportType,
			blc.gameID AS BetType,
			blc.transdate,
			blc.winlostdate,
			blc.status,
			blc.statusID,
			blc.odds,
			@CurrencyName AS Currency,
			blc.stake,
			blc.actual_stake,
			(blc.winlost - blc.actual_stake) AS WinLost,
			blc.playercomm AS commission,
			blc.spositiontaking,
			blc.mpositiontaking,
			blc.apositiontaking,
			blc.swinlost,
			blc.mwinlost,
			blc.awinlost,
			blc.sdiscount,
			blc.adiscount,
			blc.discount,
			(blc.scomm - blc.acomm) AS scomm,
			(blc.acomm - blc.comm) AS acomm,
			(blc.comm - blc.playercomm) AS comm,
			blc.ip,
			blc.transdesc,
			CASE
				WHEN sbt.productID IN (21) THEN blc.TranId3rd
				ELSE ''
			END AS BetCheck,
			CASE
				WHEN sbt.productID IN (21) THEN blc.GameId3rd
				ELSE ''
			END AS MatchCode
		FROM dbo.bettransLC AS blc WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON blc.gameID = sbt.Bettype
		WHERE blc.custid = @CustId 
			AND blc.RefNo = @RefNo
			AND blc.statusID IN (SELECT statusId FROM @tmpStatus)
	END
	ELSE IF @WhTicket = 2
	BEGIN
		INSERT INTO #Data
		SELECT
			blc.transid,
			blc.productID AS SportType,
			blc.gameID AS BetType,
			blc.transdate,
			blc.winlostdate,
			blc.status,
			blc.statusID,
			blc.odds,
			@CurrencyName AS Currency,
			blc.stake,
			blc.actual_stake,
			(blc.winlost - blc.actual_stake) AS WinLost,
			blc.playercomm AS commission,
			blc.spositiontaking,
			blc.mpositiontaking,
			blc.apositiontaking,
			blc.swinlost,
			blc.mwinlost,
			blc.awinlost,
			blc.sdiscount,
			blc.adiscount,
			blc.discount,
			(blc.scomm - blc.acomm) AS scomm,
			(blc.acomm - blc.comm) AS acomm,
			(blc.comm - blc.playercomm) AS comm,
			blc.ip,
			blc.transdesc,
			CASE
				WHEN sbt.productID IN (21) THEN blc.TranId3rd
				ELSE ''
			END AS BetCheck,
			CASE
				WHEN sbt.productID IN (21) THEN blc.GameId3rd
				ELSE ''
			END AS MatchCode
		FROM dbo.bettransLC14 AS blc WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON blc.gameID = sbt.Bettype
		WHERE blc.custid = @CustId AND blc.RefNo = @RefNo
	END
	ELSE IF @WhTicket = 3
	BEGIN
		INSERT INTO #Data
		SELECT
			blc.transid,
			blc.productID AS SportType,
			blc.gameID AS BetType,
			blc.transdate,
			blc.winlostdate,
			blc.status,
			blc.statusID,
			blc.odds,
			@CurrencyName AS Currency,
			blc.stake,
			blc.actual_stake,
			(blc.winlost - blc.actual_stake) AS WinLost,
			blc.playercomm AS commission,
			blc.spositiontaking,
			blc.mpositiontaking,
			blc.apositiontaking,
			blc.swinlost,
			blc.mwinlost,
			blc.awinlost,
			blc.sdiscount,
			blc.adiscount,
			blc.discount,
			(blc.scomm - blc.acomm) AS scomm,
			(blc.acomm - blc.comm) AS acomm,
			(blc.comm - blc.playercomm) AS comm,
			blc.ip,
			blc.transdesc,
			CASE
				WHEN sbt.productID IN (21) THEN blc.TranId3rd
				ELSE ''
			END AS BetCheck,
			CASE
				WHEN sbt.productID IN (21) THEN blc.GameId3rd
				ELSE ''
			END AS MatchCode
		FROM bodb_Archive.dbo.bettransLC_bk AS blc WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON blc.gameID = sbt.Bettype
		WHERE blc.custid = @CustId AND blc.RefNo = @RefNo
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


GO
GRANT	VIEW DEFINITION	ON	Acc_BetList_LC_Detail	TO	vnteam
GRANT	EXECUTE	ON	Acc_BetList_LC_Detail	TO	bodbExtAccNet
GRANT	EXECUTE	ON	Acc_BetList_LC_Detail	TO	bodbDownlineNetView
GRANT	EXECUTE	ON	Acc_BetList_LC_Detail	TO	bodbDownlineNet
GRANT	EXECUTE	ON	Acc_BetList_LC_Detail	TO	bodbAdminNet
GO
