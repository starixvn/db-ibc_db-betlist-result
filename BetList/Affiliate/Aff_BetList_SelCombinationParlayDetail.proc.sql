/*<info serverAlias="DBEXT-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/
USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Aff_User_BetListSystemParlayDetail]    Script Date: 10/17/2014 12:47:09 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Aff_BetList_SelCombinationParlayDetail]
	@UserId				INT
	,@Refno				BIGINT
	,@TransId			BIGINT			= 0
	,@BetId				BIGINT			= 0
	,@CustId			INT				= 0
	,@MoveBetsDay		SMALLDATETIME
	,@BalanceUpDay		SMALLDATETIME
	,@Outstanding		MONEY			= 0 OUTPUT
	,@OutstandingUSD	MONEY			= 0 OUTPUT
	,@OutstandingEUR	MONEY			= 0 OUTPUT
	,@OutstandingMYR	MONEY			= 0 OUTPUT
	,@OutstandingGBP	MONEY			= 0 OUTPUT
AS

/*
	Created: 20141017@Bobby
	Task: Get Betlist Parlay by TransID
	DB: DBEXT.bodb02
	Orgiginal: dbo.Lrf_BetList_SelCombinationParlayDetail

	Revisions:
		- 20141017@Bobby: Initial SP
		- 20160414@Bobby: #56136 - Support Combo Parlay
		- 20161013@Kos: Add product bet type range for sub tickets [Redmine: #65045]
		- 20170324@Kos: Hotfix - Mix Parlay duplicate ticket detail [Redmine: #73984]
*/

BEGIN
	SET NOCOUNT ON

	-- Get Sport Bettype Matrix
	DECLARE @SportBettype TABLE(ProductId TINYINT, Bettype SMALLINT, EventType TINYINT)

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype
	SELECT ProductID, BetType, EventType
	FROM dbo.f_SportBettypeMatrix_Sel (1, 0, 0, 2, '', '', @IsTest)

	DECLARE @currency INT
	DECLARE
		@USD FLOAT,
		@EUR FLOAT,
		@MYR FLOAT,
		@GBP FLOAT

	DECLARE @tmpBettrans AS TABLE(
		TransId	BIGINT,
		RefNo	BIGINT,
		Stake	MONEY,
		--for generating combination parlays if not in BetParlayResult
		N		TINYINT,	-- Number of selection
		Bitmap	INT	-- Combination Bitmap
	)

	DECLARE @parlay_base AS TABLE (
		TransId			BIGINT,
		RefNo			BIGINT,
		MatchId			INT,
		MatchDate		DATETIME,
		--for generating combination parlays
		RN				TINYINT,	-- set No. for selection in the combination
		Cnt				TINYINT,	-- total selection count, base on bettransm/14
		bCnt			TINYINT		-- total selection count, stored in bettrans
	)

	DECLARE @tmpResults TABLE (
		WinLostDate	DATETIME,
		TransId		BIGINT,
		Serial		BIGINT,
		StatusId	INT,
		Status		VARCHAR(20),
		Modds		MONEY,
		Stake		MONEY,
		WinLost		MONEY,
		Comm		MONEY,
		PlayerComm	MONEY
	)

	DECLARE @betParlayDetail TABLE (
		RefNo	BIGINT,
		Serial	INT,
		MatchId	INT
	)

	DECLARE @tmpMatch AS TABLE(
		Serial	BIGINT,
		HomeId	INT,
		AwayId	INT
	)

	DECLARE @minMatchdate DATETIME,
			@maxMatchdate DATETIME


	SELECT @currency = currency
	FROM dbo.custinfo WITH (NOLOCK)
	WHERE custid = @CustId

	-- Get bettransm data
	INSERT INTO @parlay_base (
		TransId,
		RefNo,
		MatchId,
		MatchDate )
	SELECT
		bm.transid,
		bm.refno,
		m.matchid,
		bm.matchdate
	FROM dbo.bettransm AS bm WITH (NOLOCK)
		INNER JOIN dbo.match AS m WITH (NOLOCK) ON bm.matchid = m.matchid
		INNER JOIN @SportBettype AS sbt ON bm.bettype = sbt.Bettype
	WHERE refno = @RefNo AND custid = @CustId

	UNION

	SELECT
		bm.transid,
		bm.refno,
		m.matchid,
		bm.matchdate
	FROM dbo.bettransm14 AS bm WITH (NOLOCK)
		INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON bm.matchid = m.matchid
		INNER JOIN @SportBettype AS sbt ON bm.bettype = sbt.Bettype
	WHERE refno = @RefNo

	UNION

	SELECT
		bm.transid,
		bm.refno,
		m.matchid,
		bm.matchdate
	FROM DBACC.bodb_Archive.dbo.bettransm AS bm WITH (NOLOCK)
		INNER JOIN DBACC.bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON bm.matchid = m.matchid
		INNER JOIN @SportBettype AS sbt ON bm.bettype = sbt.Bettype
	WHERE refno = @RefNo

	SELECT	@minMatchdate = MIN(matchdate),
			@maxMatchdate = MAX(matchdate)
	FROM @parlay_base

	-- Get bettrans and BetParlayResult data
	IF @minMatchdate < @BalanceUpDay
	BEGIN
		INSERT INTO @tmpBettrans
		SELECT
			transid,
			refno,
			stake,
			CASE
				WHEN betcheck IS NULL THEN LEN(betteam)		-- old Parlay tickets
				ELSE hdp2									-- new Parlay tickets
			END AS N,
			CASE
				WHEN betcheck IS NULL THEN hdp2				-- old Parlay tickets
				ELSE betcheck								-- new Parlay tickets
			END AS Bitmap
		FROM DBACC.bodb_Archive.dbo.bettrans_bk b WITH(NOLOCK) 
		WHERE custid = @CustId
			AND refno = @RefNo
			AND matchid = 29
			AND bettype = 29
			AND transid NOT IN (SELECT transid FROM @tmpBettrans)
	
		INSERT INTO @tmpResults (
			WinLostDate,
			Serial,
			Modds,
			Stake,
			WinLost,
			StatusId,
			Comm,
			PlayerComm)
		SELECT
			b.winlostdate,
			b.serial,
			b.modds,
			b.stake,
			b.winlost,
			b.statusid,
			b.comm,
			CASE WHEN b.statusid IN (112, 113) THEN b.playercomm ELSE 0 END AS playercomm
		FROM DBACC.bodb_Archive.dbo.BetParlayResult AS b WITH (NOLOCK)
		WHERE refno = @RefNo
	END

	IF @minMatchdate <= @MoveBetsDay	--- bettrans14 range
	BEGIN
		INSERT INTO @tmpBettrans
		SELECT
			transid,
			refno,
			stake,
			CASE
				WHEN betcheck IS NULL THEN LEN(betteam)		-- old Parlay tickets
				ELSE hdp2									-- new Parlay tickets
			END AS N,
			CASE
				WHEN betcheck IS NULL THEN hdp2				-- old Parlay tickets
				ELSE betcheck								-- new Parlay tickets
			END AS Bitmap
		FROM dbo.bettrans14 AS b WITH (NOLOCK)
		WHERE custid = @CustId
			AND refno = @RefNo
			AND matchid = 29
			AND bettype = 29
			AND transid NOT IN (SELECT transid FROM @tmpBettrans)
	END

	IF @maxMatchdate > @MoveBetsDay  --- get data from bettrans
	BEGIN
		INSERT INTO @tmpBettrans
		SELECT
			transid,
			refno,
			stake,
			CASE
				WHEN betcheck IS NULL THEN LEN(betteam)		-- old Parlay tickets
				ELSE hdp2									-- new Parlay tickets
			END AS N,
			CASE
				WHEN betcheck IS NULL THEN hdp2				-- old Parlay tickets
				ELSE betcheck								-- new Parlay tickets
			END AS Bitmap
		FROM dbo.bettrans AS b WITH (NOLOCK)
		WHERE custid = @CustId 
			AND refno = @RefNo
			AND matchid = 29
			AND bettype = 29
			AND transid NOT IN (SELECT transid FROM @tmpBettrans)
	END

	INSERT INTO @tmpResults (
		WinLostDate,
		Serial,
		Modds,
		Stake,
		WinLost,
		StatusId,
		Comm,
		PlayerComm)
	SELECT
		b.winlostdate,
		b.Serial,
		b.mOdds,
		b.stake,
		b.winlost,
		b.statusid,
		b.comm,
		CASE WHEN b.statusid IN (112, 113) THEN b.playercomm ELSE 0 END AS playercomm 
	FROM dbo.BetParlayResult AS b WITH (NOLOCK) 
	WHERE refno = @RefNo AND serial NOT IN (SELECT serial FROM @tmpResults)

	-- Generate betparlay detail
	IF @minMatchdate < @BalanceUpday
	BEGIN
		;WITH sub AS 
		(
			SELECT ROW_NUMBER() OVER (ORDER BY matchid) RN, matchid FROM @parlay_base
		)
		UPDATE pb
		SET RN = sub.RN
		FROM sub
			INNER JOIN @parlay_base AS pb ON sub.matchid = pb.matchid

		-- prepare N
		;WITH sub AS (SELECT COUNT(*) cnt FROM @parlay_base)
		UPDATE pb
		SET CNT = sub.cnt,
			bCNT = t.N
		FROM sub,
			@parlay_base AS pb,
			@tmpBettrans AS t
	
		IF NOT EXISTS(SELECT 1 FROM @parlay_base WHERE cnt <> bCnt)
		BEGIN
			INSERT INTO @betParlayDetail
			SELECT
				pb.RefNo,
				rc.Serial,
				pb.MatchId
			FROM
				@parlay_base AS pb
				INNER JOIN @tmpBettrans AS tb ON pb.RefNo = tb.RefNo
				INNER JOIN dbo.RefCombinationSet AS rcs WITH (NOLOCK) ON pb.CNT = rcs.N AND (tb.Bitmap & rcs.bitmap) > 0
				INNER JOIN dbo.RefCombination AS rc WITH (NOLOCK) ON rcs.N = rc.N AND rcs.R = rc.R AND pb.RN = rc.seq
		END
	END
	ELSE
	BEGIN
		INSERT INTO @betParlayDetail
		SELECT
			refno,
			serial,
			matchid
		FROM dbo.BetParlayDetail WITH (NOLOCK)
		WHERE refno = @RefNo
	END

	-- Get homeid, awayid
	IF @MinMatchdate < @BalanceUpday
	BEGIN
		INSERT INTO @tmpMatch
		SELECT
			p.serial,
			m.homeid,
			m.awayid
		FROM @tmpResults AS p
			INNER JOIN @betParlayDetail AS b ON p.Serial = b.Serial
			INNER JOIN DBACC.bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON b.MatchId = m.matchid
		WHERE p.statusid NOT IN (0, 1, 113)
	END

	IF @MinMatchdate <= @MoveBetsDay
	BEGIN
		INSERT INTO @tmpMatch
		SELECT
			p.serial,
			m.homeid,
			m.awayid
		FROM @tmpResults AS p
			INNER JOIN @betParlayDetail AS b ON p.Serial = b.Serial
			INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
		WHERE p.statusid NOT IN (0, 1, 113)
	END

	IF @MaxMatchdate > @MoveBetsDay
	BEGIN
		INSERT INTO @tmpMatch
		SELECT
			p.serial,
			m.homeid,
			m.awayid
		FROM @tmpResults AS p
			INNER JOIN @betParlayDetail AS b ON p.Serial = b.Serial
			INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
		WHERE p.statusid NOT IN (0, 1, 113)
	END

	-- Calculate outstanding
	SELECT @Outstanding = MAX(Stake)
	FROM @tmpBettrans

	SELECT @Outstanding = @Outstanding - ISNULL(SUM(Stake), 0)
	FROM @tmpResults
	WHERE StatusId NOT IN (0, 1)

	DECLARE @Today SMALLDATETIME
	
	SELECT @Today = CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120)

	SELECT
		@USD = e.USD,
		@EUR = e.EUR,
		@MYR = e.MYR,
		@GBP = e.GBP
	FROM (SELECT * FROM Lrf_f_GetExchangeDaily(@Today, @Today)) AS e
	WHERE e.ExchangeDate = @Today AND e.ExchangeId = @currency

	SELECT @Outstanding = ISNULL(@Outstanding, 0)
	SELECT @OutstandingUSD = ISNULL(@Outstanding, 0) * @USD
	SELECT @OutstandingEUR = ISNULL(@Outstanding, 0) * @EUR
	SELECT @OutstandingMYR = ISNULL(@Outstanding, 0) * @MYR
	SELECT @OutstandingGBP = ISNULL(@Outstanding, 0) * @GBP

	DECLARE @Fromdate DATETIME
	DECLARE @Todate DATETIME 

	SELECT @Fromdate = MIN(winlostdate),
		@Todate = MAX(winlostdate)
	FROM @tmpResults

	--select * FROM @tmpResults
	-- Return combo detail
	SELECT DISTINCT
		0 AS [Order],
		b.WinLostDate,
		0 AS TransId,
		b.Serial,
		b.StatusId,
		CASE b.StatusId
			WHEN 101 THEN 'REJECT'
			WHEN 102 THEN 'VOID'
			WHEN 103 THEN 'REFUND'
			WHEN 111 THEN 'DRAW'
			WHEN 112 THEN 'WON'
			ELSE ''
		END AS status,
		b.Modds,
		b.Stake,
		CAST (b.Stake * e.USD AS MONEY) AS StakeUSD,
		CAST (b.Stake * e.EUR AS MONEY) AS StakeEUR,
		CAST (b.Stake * e.MYR AS MONEY) AS StakeMYR,
		CAST (b.Stake * e.GBP AS MONEY) AS StakeGBP,
		b.WinLost - b.Stake AS WinLost,
		CAST ((b.WinLost - b.Stake) * e.USD AS MONEY) AS WinLostUSD,
		CAST ((b.WinLost - b.Stake) * e.EUR AS MONEY) AS WinLostEUR,
		CAST ((b.WinLost - b.Stake) * e.MYR AS MONEY) AS WinLostMYR,
		CAST ((b.WinLost - b.Stake) * e.GBP AS MONEY) AS WinLostGBP,
		b.Comm,
		CAST (b.Comm * e.USD AS MONEY) AS CommUSD,
		CAST (b.Comm * e.EUR AS MONEY) AS CommEUR,
		CAST (b.Comm * e.MYR AS MONEY) AS CommMYR,
		CAST (b.Comm * e.GBP AS MONEY) AS CommGBP,
		b.PlayerComm,
		CAST(b.PlayerComm * e.USD AS MONEY) AS PlayerCommUSD,
		CAST(b.PlayerComm * e.EUR AS MONEY) AS PlayerCommEUR,
		CAST(b.PlayerComm * e.MYR AS MONEY) AS PlayerCommMYR,
		CAST(b.PlayerComm * e.GBP AS MONEY) AS PlayerCommGBP
	FROM @tmpResults AS b
		INNER JOIN (SELECT * FROM Lrf_f_GetExchangeDaily(@FromDate, @ToDate)) AS e
			ON e.ExchangeDate = b.WinLostDate AND e.ExchangeId = @currency
	WHERE b.StatusId NOT IN (0, 1, 113)

	UNION ALL

	SELECT DISTINCT
		999 AS [Order],
		b.WinLostDate,
		0 AS TransId,
		0 AS Serial,
		113 AS StatusId,
		'LOSE' AS Status,
		0 AS Modds,
		SUM(b.Stake) AS Stake,
		CAST(SUM(b.Stake * e.USD) AS MONEY) AS StakeUSD,
		CAST(SUM(b.Stake * e.EUR) AS MONEY) AS StakeEUR,
		CAST(SUM(b.Stake * e.MYR) AS MONEY) AS StakeMYR,
		CAST(SUM(b.Stake * e.GBP) AS MONEY) AS StakeGBP,
		SUM(b.WinLost - b.Stake) AS WinLost,
		CAST(SUM((b.WinLost - b.Stake) * e.USD) AS MONEY) AS WinLostUSD,
		CAST(SUM((b.WinLost - b.Stake) * e.EUR) AS MONEY) AS WinLostEUR,
		CAST(SUM((b.WinLost - b.Stake) * e.MYR) AS MONEY) AS WinLostMYR,
		CAST(SUM((b.WinLost - b.Stake) * e.GBP) AS MONEY) AS WinLostGBP,
		SUM(b.Comm) AS Comm,
		CAST(SUM(b.Comm * e.USD) AS MONEY) AS CommUSD,
		CAST(SUM(b.Comm * e.EUR) AS MONEY) AS CommEUR,
		CAST(SUM(b.Comm * e.MYR) AS MONEY) AS CommMYR,
		CAST(SUM(b.Comm * e.GBP) AS MONEY) AS CommGBP,
		SUM(b.PlayerComm) AS PlayerComm,
		CAST(SUM(b.PlayerComm * e.USD) AS MONEY) AS PlayerCommUSD,
		CAST(SUM(b.PlayerComm * e.EUR) AS MONEY) AS playercommeur,
		CAST(SUM(b.PlayerComm * e.MYR) AS MONEY) AS playercommmyr,
		CAST(SUM(b.PlayerComm * e.GBP) AS MONEY) AS playercommgbp
	FROM @tmpResults AS b
		INNER JOIN (SELECT * FROM Lrf_f_GetExchangeDaily(@FromDate, @ToDate)) AS e
			ON e.ExchangeDate = b.WinLostDate AND e.ExchangeId = @currency
	WHERE b.StatusId = 113
	GROUP BY b.WinLostDate
	ORDER BY
		[Order] ASC,
		b.WinLostDate ASC

	SELECT DISTINCT * FROM @tmpMatch
END
GO

GRANT EXECUTE ON [dbo].[Aff_BetList_SelCombinationParlayDetail] TO [bodbAdminNet] AS [dbo]
GO

GRANT EXECUTE ON [dbo].[Aff_BetList_SelCombinationParlayDetail] TO [bodbDownlineNet] AS [dbo]
GO  

