/*<info serverAlias="DBACC-bodb02" executers="wsv_nap,wsv_alp, wsv_alpv" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Acc_BetList_G_Detail]
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
	Created: Kos@20151012
	Task: Get ticket detail from table betransg
	DB: DBACC.bodb02
	Original:
	Revisions:
		- 20200410@Kos: Support BBIN [Redmine: #131362]
		- 20211004@Razor: Extend Data type of IP v6 [Redmine: #90903]
		- 20211025@Razor: Decompress IP on BK range [Redmine: #90903]
		- 20211115@Razor: Enhance to get Detail ticket [Redmine: #164614]
		- 20211222@Razor: BBIN Support Third Party Result API [Redmine: #165158]
		- 20231019@Razor: Return Device Type info [Redmine: #192667]
		- 20240105@Razor: Extend data type [Redmine: #199259]
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
	WHERE ProductID IN (47)	-- Support BBIN only

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
		SportType		SMALLINT,
		BetType			SMALLINT,
		TransDate		DATETIME,
		WinLostDate		SMALLDATETIME,
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
		TransDesc		NVARCHAR(2000),
		BetCheck		NVARCHAR(200),
		MatchCode		VARCHAR(50),
		BetTeam			NVARCHAR(50),
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
		INNER JOIN dbo.Exchange AS ex WITH (NOLOCK) ON b.currency = ex.exchangeid
	WHERE b.transid = @RefNo
		AND b.winlostdate > @MoveBetsDay

	IF @CurrencyName IS NULL
	BEGIN
		SELECT @CurrencyName = ex.currency,
			@WhTicket = 2
		FROM dbo.bettrans14 AS b WITH (NOLOCK)
			INNER JOIN dbo.Exchange AS ex WITH (NOLOCK) ON b.currency = ex.exchangeid
		WHERE b.transid = @RefNo
			AND b.winlostdate BETWEEN @BalanceUpDay AND @MoveBetsDay

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
		INSERT INTO #Data
		SELECT
			bg.transid,
			bg.custid,
			bg.matchid AS SportType,
			bg.bettype,
			bg.transdate,
			bg.winlostdate,
			bg.status,
			bg.statusID,
			bg.odds,
			@CurrencyName AS Currency,
			bg.stake,
			bg.actual_stake,
			bg.winlost - bg.actual_stake AS WinLost,
			bg.playercomm AS Commission,
			bg.spositiontaking,
			bg.mpositiontaking,
			bg.apositiontaking,
			bg.swinlost,
			bg.mwinlost,
			bg.awinlost,
			bg.sdiscount,
			bg.adiscount,
			bg.discount,
			bg.scomm - bg.acomm AS SComm,
			bg.acomm - bg.comm AS AComm,
			bg.comm - bg.playercomm AS Comm,
			b.ip,
			bg.transdesc,
			ISNULL(bg.BetID3rd, '') AS BetCheck,
			'' AS MatchCode,
			ISNULL(bg.betteam, '') AS BetTeam,
			b.currency,
			bg.SiteId,
			bg.DeviceType
		FROM dbo.bettransg AS bg WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON bg.bettype = sbt.Bettype
			INNER JOIN dbo.bettrans AS b WITH (NOLOCK)
				ON b.transid = bg.refno
				AND b.custid = bg.custid
				AND sbt.ProductID = 47
		WHERE bg.refno = @RefNo
			AND bg.statusID IN (SELECT statusId FROM @tmpStatus)
	END
	ELSE IF @WhTicket = 2
	BEGIN
		INSERT INTO #Data
		SELECT
			bg.transid,
			bg.custid,
			bg.matchid AS SportType,
			bg.bettype,
			bg.transdate,
			bg.winlostdate,
			bg.status,
			bg.statusID,
			bg.odds,
			@CurrencyName AS Currency,
			bg.stake,
			bg.actual_stake,
			bg.winlost - bg.actual_stake AS WinLost,
			bg.playercomm AS Commission,
			bg.spositiontaking,
			bg.mpositiontaking,
			bg.apositiontaking,
			bg.swinlost,
			bg.mwinlost,
			bg.awinlost,
			bg.sdiscount,
			bg.adiscount,
			bg.discount,
			bg.scomm - bg.acomm AS SComm,
			bg.acomm - bg.comm AS AComm,
			bg.comm - bg.playercomm AS Comm,
			b.ip,
			bg.transdesc,
			ISNULL(bg.BetID3rd, '') AS BetCheck,
			'' AS MatchCode,
			ISNULL(bg.betteam, '') AS BetTeam,
			b.currency,
			bg.SiteId,
			bg.DeviceType
		FROM dbo.bettransg14 AS bg WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON bg.bettype = sbt.Bettype
			INNER JOIN dbo.bettrans14 AS b WITH (NOLOCK)
				ON b.transid = bg.refno
				AND b.custid = bg.custid
				AND sbt.ProductID = 47
		WHERE bg.refno = @RefNo
			AND bg.statusID IN (SELECT statusId FROM @tmpStatus)
	END
	ELSE IF @WhTicket = 3
	BEGIN
		INSERT INTO #Data
		SELECT
			bg.transid,
			bg.custid,
			bg.matchid AS SportType,
			bg.bettype,
			bg.transdate,
			bg.winlostdate,
			bg.status,
			bg.statusID,
			bg.odds,
			@CurrencyName AS Currency,
			bg.stake,
			bg.actual_stake,
			bg.winlost - bg.actual_stake AS WinLost,
			bg.playercomm AS Commission,
			bg.spositiontaking,
			bg.mpositiontaking,
			bg.apositiontaking,
			bg.swinlost,
			bg.mwinlost,
			bg.awinlost,
			bg.sdiscount,
			bg.adiscount,
			bg.discount,
			bg.scomm - bg.acomm AS SComm,
			bg.acomm - bg.comm AS AComm,
			bg.comm - bg.playercomm AS Comm,
			dp.ip,
			bg.transdesc,
			ISNULL(bg.BetID3rd, '') AS BetCheck,
			'' AS MatchCode,
			ISNULL(bg.betteam, '') AS BetTeam,
			b.currency,
			bg.SiteId,
			bg.DeviceType
		FROM bodb_Archive.dbo.bettransg AS bg WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON bg.bettype = sbt.Bettype
			INNER JOIN bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK)
				ON b.transid = bg.refno
				AND b.custid = bg.custid
				AND sbt.ProductID = 47
			CROSS APPLY dbo.f_IP_Decompress(b.Ip) AS dp
		WHERE bg.refno = @RefNo
			AND bg.statusID IN (SELECT statusId FROM @tmpStatus)
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
	ORDER BY t.TransId

	DROP TABLE #Data
END
GO