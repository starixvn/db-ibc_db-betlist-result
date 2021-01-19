/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet,bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0" isNested="0"></info>*/

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
	Task: Get ticket detail from table betransRnG (Microgaming RNG Game)
	DB: DBACC.bodb02
	Original:
	Revisions:
		- 20151030@Kos: Change ProductId/SportType of Microgaming RNG Casino
		- 20151229@Kos: Support RNG Casino Single Wallet and use SportBettypeMatrix [Redmine: #48958]
		- 20160304@Kos: Add MatchCode column
		- 20160331@Kos: Support Voidbridge [#Redmine: 54925]
		- 20160426@Kos: Support paging
		- 20160704@Kos: Include Void/Rejected detail ticket in TransType = 1 [Redmine: #59366]
		- 20161020@Kos: Support Fishing World [#Redmine: 65934]
		- 20180328@Kos: Increase Transdesc length to 1000 [Redmine: #92841]
		- 20180330@Kos: Support ONERnG Jackpot [#Redmine: 88652]
		- 20180405@Kos: Support Pragmatic Casino [#Redmine: 92160]
		- 20181109@Kos: Move from DBAGE to DBACC [#Redmine: 104521]
		- 20190321@Kos: Support Pragmatic Promotion Prize [#Redmine: 108117]
		- 20190626@Kos: Change code to prevent wrong index using [#Redmine: 115624]
		- 20190611@Kos: Support Card Club [#Redmine: 107645]
		- 20190829@Kos: Don't support inactive products anymore [Redmine: #119100]
		- 20191029@Kos: Support Spadegaming [Redmine: #122140]
		- 20200322@Kos: Support Saba.club [Redmine: #130769]
		- 20200526@Kos: Support RNG War [Redmine: #132017]
		- 20200709@Kos: Support PP Jackpot [Redmine: #137284]
		- 20200731@Kos: Support Saba.club Result [Redmine: #137680]
		- 20200808@Kos: Support PG Soft [Redmine: #137769]
		- 20200919@Kos: Support Joker [Redmine: #137942]
		- 20200930@Kos: Support GameId3rd for PG Soft [Redmine: #137769]
		- 20201231@Kos: Support MaxGame [Redmine: #147568]
					- Return additional column EventDate DATETIME
		- 20210119@Kos: Support Saba.club Jackpot Contribution and Jackpot Prize tickets [Redmine: #147709]

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
	-- Support RNG Casino Single Wallet, Voidbridge, Fishing World, Pragmatic Casino, Card Club, Spadegaming, Saba.club, PG Soft, Joker
	DECLARE @SportBettype TABLE (ProductID TINYINT, BetType SMALLINT, EventType TINYINT, SubProduct VARCHAR(500))

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype
	SELECT ProductID, BetType, EventType, SubProduct
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
	WHERE ProductID IN (22, 24, 32, 34, 36, 42, 50, 55, 56, 60)
		OR (ProductID = 6 AND SubProduct <> '')

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
	DECLARE @Data TABLE (
		TransId			BIGINT,
		CustId			INT,
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
		MatchCode		VARCHAR(1000),
		EventDate		DATETIME,
		OddsSpread		MONEY,
		BetdaqId		BIGINT,
		ExtraInfo		VARCHAR(1000)
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
			FROM bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK)
				INNER JOIN dbo.Exchange AS ex WITH (NOLOCK) ON b.currency = ex.exchangeid
			WHERE b.transid = @RefNo
		END
	END

	-- Get ticket
	IF @WhTicket = 1
	BEGIN
		INSERT INTO @Data
		SELECT
			brng.transid,
			brng.custid,
			brng.productID AS SportType,
			brng.gameID AS BetType,
			brng.transdate,
			brng.winlostdate,
			brng.status,
			brng.statusID,
			CASE
				WHEN sbt.ProductID IN (6, 32, 42) AND brng.statusID IN (111, 112, 113) THEN ISNULL(brng.ContributionRate, 0)
				ELSE brng.odds
			END AS Odds,
			@CurrencyName AS Currency,
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
			brng.TranId3rd AS BetCheck,
			CASE
				WHEN sbt.productID IN (24, 32, 34, 36) THEN brng.Additional
				WHEN sbt.productID IN (42) THEN ISNULL(brng.SiteID, '')
				WHEN sbt.productID IN (55, 56) THEN brng.GameId3rd
				ELSE ''
			END AS MatchCode,
			CASE
				WHEN sbt.productID IN (60) THEN brng.Transdate3rd
				ELSE ''
			END AS EventDate,
			CASE
				WHEN sbt.ProductID IN (6, 32, 42) AND brng.statusID IN (111, 112, 113) THEN ISNULL(brng.BetStake, 0)
				ELSE 0
			END AS OddsSpread,
			CASE
				WHEN sbt.ProductID IN (6, 32, 42) THEN ISNULL(brng.RefNo2, -1)
				ELSE -1
			END AS BetdaqId,
			CASE
				WHEN sbt.ProductID IN (6, 32, 42) THEN ISNULL(brng.JackpotInfo, '')
				ELSE ''
			END AS ExtraInfo
		FROM dbo.bettransRnG AS brng WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON brng.gameID = sbt.Bettype
		WHERE brng.RefNo = @RefNo
			AND brng.statusID IN (SELECT statusId FROM @tmpStatus)
	END
	ELSE IF @WhTicket = 2
	BEGIN
		INSERT INTO @Data
		SELECT
			brng.transid,
			brng.custid,
			brng.productID AS SportType,
			brng.gameID AS BetType,
			brng.transdate,
			brng.winlostdate,
			brng.status,
			brng.statusID,
			CASE
				WHEN sbt.ProductID IN (6, 32, 42) AND brng.statusID IN (111, 112, 113) THEN ISNULL(brng.ContributionRate, 0)
				ELSE brng.odds
			END AS Odds,
			@CurrencyName AS Currency,
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
			brng.TranId3rd AS BetCheck,
			CASE
				WHEN sbt.productID IN (24, 32, 34, 36) THEN brng.Additional
				WHEN sbt.productID IN (42) THEN ISNULL(brng.SiteID, '')
				WHEN sbt.productID IN (55, 56) THEN brng.GameId3rd
				ELSE ''
			END AS MatchCode,
			CASE
				WHEN sbt.productID IN (60) THEN brng.Transdate3rd
				ELSE ''
			END AS EventDate,
			CASE
				WHEN sbt.ProductID IN (6, 32, 42) AND brng.statusID IN (111, 112, 113) THEN ISNULL(brng.BetStake, 0)
				ELSE 0
			END AS OddsSpread,
			CASE
				WHEN sbt.ProductID IN (6, 32, 42) THEN ISNULL(brng.RefNo2, -1)
				ELSE -1
			END AS BetdaqId,
			CASE
				WHEN sbt.ProductID IN (6, 32, 42) THEN ISNULL(brng.JackpotInfo, '')
				ELSE ''
			END AS ExtraInfo
		FROM dbo.bettransRnG14 AS brng WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON brng.gameID = sbt.Bettype
		WHERE brng.RefNo = @RefNo
	END
	ELSE IF @WhTicket = 3
	BEGIN
		INSERT INTO @Data
		SELECT
			brng.transid,
			brng.custid,
			brng.productID AS SportType,
			brng.gameID AS BetType,
			brng.transdate,
			brng.winlostdate,
			brng.status,
			brng.statusID,
			CASE
				WHEN sbt.ProductID IN (6, 32, 42) AND brng.statusID IN (111, 112, 113) THEN ISNULL(brng.ContributionRate, 0)
				ELSE brng.odds
			END AS Odds,
			@CurrencyName AS Currency,
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
			brng.TranId3rd AS BetCheck,
			CASE
				WHEN sbt.productID IN (24, 32, 34, 36) THEN brng.Additional
				WHEN sbt.productID IN (55, 56) THEN brng.GameId3rd
				ELSE ''
			END AS MatchCode,
			CASE
				WHEN sbt.productID IN (60) THEN brng.Transdate3rd
				ELSE ''
			END AS EventDate,
			CASE
				WHEN sbt.ProductID IN (6, 32, 42) AND brng.statusID IN (111, 112, 113) THEN ISNULL(brng.BetStake, 0)
				ELSE 0
			END AS OddsSpread,
			CASE
				WHEN sbt.ProductID IN (6, 32, 42) THEN ISNULL(brng.RefNo2, -1)
				ELSE -1
			END AS BetdaqId,
			CASE
				WHEN sbt.ProductID IN (6, 32, 42) THEN ISNULL(brng.JackpotInfo, '')
				ELSE ''
			END AS ExtraInfo
		FROM bodb_Archive.dbo.bettransRnG_bk AS brng WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON brng.gameID = sbt.Bettype
		WHERE brng.RefNo = @RefNo
	END

	DELETE FROM @Data
	WHERE CustId <> @CustId

	-- Paging
	SELECT @TotalRows = COUNT(1)
	FROM @Data

	SELECT *
	FROM (
		SELECT
			ROW_NUMBER() OVER(ORDER BY TransId ASC) AS RowNum,
			*
		FROM @Data ) AS t
	WHERE t.RowNum BETWEEN ((@PageIndex - 1) * @PageSize + 1) AND (@PageSize * @PageIndex)
	ORDER BY t.TransId ASC
END
GO
