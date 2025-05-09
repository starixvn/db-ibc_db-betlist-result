/*<info serverAlias="DBSIG-bodb02" executers="wsv_nap,wsv_alp, wsv_alpv" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[SiteDB_Acc_BetList_LC_Detail]
	@RefNo		BIGINT,
	@CustId		INT,
	@TransType	TINYINT	= 0,
	@PageIndex	INT		= 1,
	@PageSize	INT		= 1000,
	@MoveBetsDay		SMALLDATETIME,
	@BalanceUpDay	SMALLDATETIME,
	@TotalRows	INT		= 0		OUTPUT
AS

/*
	Created: 20220727@Kos
	Task: NAP/Alpha - Bet List - Ticket Detail of LC Casino products - SiteDB
	DB: DBSIG.bodb02
	Revisions:
		- 20220727@Kos: Scale out DBTRANS [Redmine: #175297]
		- 20230526@Razor: Support YeeBet [Redmine: #186547]
		- 20230909@Razor: Remove GDG, Fishing World products [Redmine: #174511]
		- 20230927@Razor: Support show max payout [Redmine: #194491]
		- 20231019@Razor: Return Device Type info [Redmine: #192667]
		- 20231108@Razor: Support WE Live Casino [Redmine: #195887]
		- 20240105@Razor: Extend data type [Redmine: #199259]
		- 20240912@Razor: Support ON Casino [Redmine: #210026]
		- 20241202@Razor: Support GPI Live Casino [Redmine: #213486]
		- 20250106@Razor: SA Gaming support Saba Plus [Redmine: #215645]
		- 20250326@Benji: Support Upcoming Product (Microgaming Live Casino, Playtech Live Casino ) [Redmine: #221188]
		- 20250410@Benji: Remove productID 101,107 (Microgaming Live Casino, Playtech Live Casino) [Redmine: #221188]
		- 20250414@Razor: Support Direct Member [Redmine: #211969]
		- 20250428@Dave: change datatype for ExchangeID [RedmineID: #225676]

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
	WHERE ProductID IN (11, 21, 39, 45, 46, 51, 52, 57, 65, 70, 76, 80) OR RefTable = 2
	-- Support AG Casino, AllBet, SA Gaming, Sexy Gaming, IBCBet Live Casino, ION, WM, Big Gaming only, PP Live Casino, FGG, YeeBet, WE

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
		BetCheck		NVARCHAR(2000),
		MatchCode		VARCHAR(50),
		BetTeam			NVARCHAR(200),
		LeagueId		INT,
		CurrencyId		SMALLINT,
		SiteId			VARCHAR(7),
		EventDate		DATETIME,
		ExtraInfo		VARCHAR(1000),
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
		INSERT INTO #Data
		SELECT
			CASE
				WHEN sbt.ProductID = 39 THEN ISNULL(bg.transid, blc.transid)
				ELSE blc.transid
			END AS TransId,
			blc.custid,
			blc.productID AS SportType,
			blc.gameID AS BetType,
			CASE
				WHEN sbt.ProductID = 39 THEN ISNULL(bg.transdate, blc.transdate)
				ELSE blc.transdate
			END AS TransDate,
			blc.winlostdate,
			CASE
				WHEN sbt.ProductID = 39 THEN ISNULL(bg.status, blc.status)
				ELSE blc.status
			END AS Status,
			CASE
				WHEN sbt.ProductID = 39 THEN ISNULL(bg.statusID, blc.statusID)
				ELSE blc.statusID
			END AS StatusId,
			CASE
				WHEN sbt.ProductID = 39 THEN ISNULL(bg.odds, blc.odds)
				ELSE blc.odds
			END AS Odds,
			@CurrencyName AS Currency,
			CASE
				WHEN sbt.ProductID = 39 THEN ISNULL(bg.stake, blc.stake)
				ELSE blc.stake
			END AS Stake,
			CASE
				WHEN sbt.ProductID = 39 THEN ISNULL(bg.actual_stake, blc.actual_stake)
				ELSE blc.actual_stake
			END AS Actual_Stake,
			CASE
				WHEN sbt.ProductID = 39 THEN ISNULL(bg.winlost - bg.actual_stake, blc.winlost - blc.actual_stake)
				ELSE blc.winlost - blc.actual_stake
			END AS WinLost,
			CASE
				WHEN sbt.ProductID = 39 THEN ISNULL(bg.playercomm, blc.playercomm)
				ELSE blc.playercomm
			END AS Commission,
			CASE
				WHEN sbt.ProductID = 39 THEN ISNULL(bg.spositiontaking, blc.spositiontaking)
				ELSE blc.spositiontaking
			END AS SPositionTaking,
			CASE
				WHEN sbt.ProductID = 39 THEN ISNULL(bg.mpositiontaking, blc.mpositiontaking)
				ELSE blc.mpositiontaking
			END AS MPositionTaking,
			CASE
				WHEN sbt.ProductID = 39 THEN ISNULL(bg.apositiontaking, blc.apositiontaking)
				ELSE blc.apositiontaking
			END AS APositionTaking,
			CASE
				WHEN sbt.ProductID = 39 THEN ISNULL(bg.swinlost, blc.swinlost)
				ELSE blc.swinlost
			END AS SWinLost,
			CASE
				WHEN sbt.ProductID = 39 THEN ISNULL(bg.mwinlost, blc.mwinlost)
				ELSE blc.mwinlost
			END AS MWinLost,
			CASE
				WHEN sbt.ProductID = 39 THEN ISNULL(bg.awinlost, blc.awinlost)
				ELSE blc.awinlost
			END AS AWinLost,
			CASE
				WHEN sbt.ProductID = 39 THEN ISNULL(bg.sdiscount, blc.sdiscount)
				ELSE blc.sdiscount
			END AS SDiscount,
			CASE
				WHEN blc.mrecommend = -4 THEN 0
				WHEN sbt.ProductID = 39 THEN ISNULL(bg.adiscount, blc.adiscount)
				ELSE blc.adiscount
			END AS ADiscount,
			CASE
				WHEN blc.recommend IN (-3, -4) THEN 0
				WHEN sbt.ProductID = 39 THEN ISNULL(bg.discount, blc.discount)
				ELSE blc.discount
			END AS Discount,
			CASE
				WHEN sbt.ProductID = 39 THEN ISNULL(bg.scomm - bg.acomm, blc.scomm - blc.acomm)
				ELSE blc.scomm - blc.acomm
			END AS SComm,
			CASE
				WHEN sbt.ProductID = 39 THEN ISNULL(bg.acomm - bg.comm, blc.acomm - blc.comm)
				ELSE blc.acomm - blc.comm
			END AS AComm,
			CASE
				WHEN sbt.ProductID = 39 THEN ISNULL(bg.comm - bg.playercomm, blc.comm - blc.playercomm)
				ELSE blc.comm - blc.playercomm
			END AS Comm,
			blc.ip,
			blc.transdesc,
			CASE
				WHEN sbt.productID = 11 THEN ''
				WHEN sbt.ProductID = 39 THEN ISNULL(bg.TransDesc, blc.TranId3rd)
				ELSE blc.TranId3rd
			END AS BetCheck,
			CASE
				WHEN sbt.productID = 11 THEN ''
				ELSE blc.GameId3rd
			END AS MatchCode,
			CASE
				WHEN sbt.productID = 39 THEN ISNULL(bg.BetID3rd, '')
				ELSE ''
			END AS BetTeam,
			0 AS LeagueId,
			blc.currency,
			blc.SiteId,
			CASE
				WHEN sbt.ProductID IN (70, 90) THEN blc.TransDate3rd
				ELSE ''
			END AS EventDate,
			CASE
				WHEN sbt.ProductID IN (39) THEN ISNULL(bg.ExtraInfo, blc.ExtraInfo)
				ELSE blc.ExtraInfo
			END,
			blc.DeviceType
		FROM dbo.bettransLC AS blc WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON blc.gameID = sbt.Bettype
			LEFT JOIN dbo.bettransg AS bg WITH (NOLOCK)
				ON bg.refno = blc.transid
				AND bg.custid = blc.custid
				AND sbt.ProductID = 39
		WHERE blc.RefNo = @RefNo
			AND blc.statusID IN (SELECT statusId FROM @tmpStatus)
	END

	DELETE FROM #Data
	WHERE CustId <> @CustId

	-- Paging
	SELECT @TotalRows = COUNT(1)
	FROM #Data

	SELECT *
	FROM (
		SELECT ROW_NUMBER() OVER(ORDER BY TransId) AS RowNum, *
		FROM #Data ) AS t
	WHERE t.RowNum BETWEEN ((@PageIndex - 1) * @PageSize + 1) AND (@PageSize * @PageIndex)
	ORDER BY t.TransId ASC

	DROP TABLE #Data
END
GO
