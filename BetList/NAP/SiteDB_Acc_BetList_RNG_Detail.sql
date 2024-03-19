/*<info serverAlias="DBSIG-bodb02" executers="wsv_nap,bodbDownlineNet, wsv_alp,bodbDownlineNetView, wsv_alpv" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[SiteDB_Acc_BetList_RNG_Detail]
	@RefNo			BIGINT,
	@CustId			INT,
	@TransType		TINYINT			= 0,
	@PageIndex		INT				= 1,
	@PageSize		INT				= 1000,
	@MoveBetsDay	SMALLDATETIME,
	@TotalRows		INT				= 0		OUTPUT
AS

/*
	Created: 20220727@Kos
	Task: NAP/Alpha - Bet List - Ticket Detail of RNG Casino products - SiteDB
	DB: DBSIG.bodb02
	Revisions:
		- 20220727@Kos: Scale out DBTRANS [Redmine: #175297]
		- 20220825@Razor: Support SEAL Entertainment [Redmine: #176210]
		- 20220909@Razor: Support Microgaming RNG Casino [Redmine: #175851]
		- 20230206@Razor: Support Jili [Redmine: #182864]
		- 20230830@Razor: Show LicTxId for MaxGame [Redmine: #193273]
		- 20230909@Razor: Remove GDG, Fishing World products [Redmine: #174511]
		- 20230927@Razor: Support show max payout [Redmine: #194491]
					- Return new JackpotInfo column
					- Return ExtraInfo for show Max Payout
		- 20231019@Razor: Return Device Type info [Redmine: #192667]
		- 20231225@Razor: Increase length of Betcheck column [Redmine: #198825]
		- 20231226@Razor: Support Live22 [Redmine: #197609]
		- 20240105@Razor: Extend data type [Redmine: #199259]
		- 20240207@Kos: Return GameId3rd to support Live22 Result [Redmine: #197609]

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
	-- Support RNG Casino Single Wallet, Voidbridge, Pragmatic Casino, Card Club, Spadegaming, Saba.club, PG Soft, Joker, MaxGame, CG, AdvantPlay
	-- AdvantPlay Mini, SEAL, MG RNGCasino, Jili, Live22
	DECLARE @SportBettype TABLE (ProductID TINYINT, BetType SMALLINT, EventType TINYINT, SubProduct VARCHAR(500))

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype
	SELECT ProductID, BetType, EventType, SubProduct
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
	WHERE ProductID IN (22, 32, 34, 36, 42, 50, 55, 56, 60, 61, 62, 66, 67, 68, 72, 73, 75, 79)
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
		Ip				VARCHAR(45),
		TransDesc		NVARCHAR(1000),
		BetCheck		NVARCHAR(200),
		MatchCode		VARCHAR(1000),
		BetTeam			NVARCHAR(100),
		EventDate		DATETIME,
		OddsSpread		MONEY,
		BetdaqId		BIGINT,
		ExtraInfo		VARCHAR(1000),
		JackpotInfo		VARCHAR(50),
		CurrencyId		TINYINT,
		SiteId			VARCHAR(7),
		DeviceType		TINYINT
	)

	-- Get currency name
	DECLARE @CurrencyName	NVARCHAR(50),
		@WhTicket			TINYINT

	SELECT @CurrencyName = ex.currency,
		@WhTicket = 1
	FROM dbo.bettrans AS b WITH (NOLOCK)
		INNER JOIN CustDB.dbo.Exchange AS ex WITH (NOLOCK) ON b.currency = ex.exchangeid
	WHERE b.transid = @RefNo
		AND b.winlostdate > @MoveBetsDay

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
				WHEN sbt.ProductID IN (6, 32, 36, 42, 66) AND brng.statusID IN (111, 112, 113) THEN ISNULL(brng.ContributionRate, 0)
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
				WHEN sbt.productID IN (42) THEN ISNULL(brng.SiteID, '')
				ELSE brng.Additional
			END AS MatchCode,
			brng.GameId3rd AS BetTeam,
			CASE
				WHEN sbt.productID IN (60) THEN brng.Transdate3rd
				ELSE ''
			END AS EventDate,
			CASE
				WHEN sbt.ProductID IN (6, 32, 36, 42, 66) AND brng.statusID IN (111, 112, 113) THEN ISNULL(brng.BetStake, 0)
				ELSE 0
			END AS OddsSpread,
			CASE
				WHEN sbt.ProductID IN (6, 32, 36, 42, 66) THEN ISNULL(brng.RefNo2, -1)
				ELSE -1
			END AS BetdaqId,
			brng.ExtraInfo,
			CASE
				WHEN sbt.ProductID IN (6, 32, 36, 42, 66) THEN ISNULL(brng.JackpotInfo, '')
				ELSE ''
			END AS JackpotInfo,
			brng.currency,
			brng.SiteId,
			brng.DeviceType
		FROM dbo.bettransRnG AS brng WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON brng.gameID = sbt.Bettype
		WHERE brng.RefNo = @RefNo
			AND brng.statusID IN (SELECT statusId FROM @tmpStatus)
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