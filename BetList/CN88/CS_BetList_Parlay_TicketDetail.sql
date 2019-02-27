/*<info serverAlias="DBACC-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[CS_BetList_Parlay_TicketDetail]
	@RefNo			BIGINT,
	@TransId		BIGINT		= 0,
	@BetId			BIGINT		= 0,
	@CustId			INT,
	@MoveBetDay		DATETIME,
	@BalanceUpDay	DATETIME,
	@Outstanding	MONEY		= 0 OUTPUT
AS

/*
	Created: Kos@20190304
	Task: Get detail of Parlay tickets of CN88
	DB: DBACC.bodb02
	Original: Acc_BetlistCombinationParlay_Details

	Revisions:
		- 20190304@Kos: Create new [Redmine: 109230]
*/

BEGIN
	SET NOCOUNT ON

	-- Get Sport Bettype Matrix (support Sportsbook only)
	DECLARE @SportBettype TABLE(ProductId TINYINT, Bettype SMALLINT, EventType TINYINT)

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype
	SELECT ProductID, BetType, EventType
	FROM dbo.f_SportBettypeMatrix_Sel (1, 0, 0, 2, '', '', @IsTest)

	DECLARE @tmpBettrans AS TABLE(
		TransId	BIGINT,
		RefNo	BIGINT,
		Stake	MONEY,
		--for generating combination parlays if not in BetParlayResult
		N		TINYINT,	-- Number of selection
		Bitmap	INT			-- Combination Bitmap
	)

	DECLARE @parlay_base AS TABLE(
		TransId		BIGINT,
		RefNo		BIGINT,
		MatchId		INT,
		MatchDate	DATETIME,
		--for generating combination parlays
		RN			TINYINT,	-- set No. for selection in the combination
		Cnt			TINYINT,	-- total selection count, base on bettransm/14
		bCnt		TINYINT		-- total selection count, stored in bettrans
	)

	DECLARE @tmpResults TABLE (
		WinLostDate DATETIME,
		TransId		BIGINT,
		Serial		BIGINT,
		StatusId	INT,
		Status		VARCHAR(20),
		Modds		MONEY,
		Stake		MONEY,
		WinLost		MONEY,
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
	WHERE bm.refno = @RefNo AND bm.custid = @CustId
	UNION
	SELECT
		bm.transid,
		bm.refno,
		m.matchid,
		bm.matchdate
	FROM dbo.bettransm14 AS bm WITH (NOLOCK)
		INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON bm.matchid = m.matchid
		INNER JOIN @SportBettype AS sbt ON bm.bettype = sbt.Bettype
	WHERE bm.refno = @RefNo
	UNION
	SELECT
		bm.transid,
		bm.refno,
		m.matchid,
		bm.matchdate
	FROM bodb_Archive.dbo.bettransm AS bm WITH (NOLOCK)
		INNER JOIN bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON bm.matchid = m.matchid
		INNER JOIN @SportBettype AS sbt ON bm.bettype = sbt.Bettype
	WHERE bm.refno = @RefNo

	SELECT
		@minMatchdate = MIN(matchdate),
		@maxMatchdate = MAX(matchdate)
	FROM @parlay_base

	-- Get bettrans and BetParlayResult data
	IF @minMatchdate < @BalanceUpDay		-- bettrans_bk range
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
				WHEN betcheck IS NULL THEN CONVERT(INT, hdp2)	-- old Parlay tickets
				ELSE CONVERT(INT, betcheck)						-- new Parlay tickets
			END AS Bitmap
		FROM bodb_Archive.dbo.bettrans_bk WITH(NOLOCK) 
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
			PlayerComm )
		SELECT
			winlostdate,
			Serial,
			mOdds,
			stake,
			winlost,
			statusid,
			playercomm
		FROM bodb_Archive.dbo.betparlayresult WITH (NOLOCK)
		WHERE refno = @RefNo
	END

	IF @minMatchdate <= @MoveBetDay		--- bettrans14 range
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
				WHEN betcheck IS NULL THEN CONVERT(INT, hdp2)	-- old Parlay tickets
				ELSE CONVERT(INT, betcheck)						-- new Parlay tickets
			END AS Bitmap
		FROM dbo.bettrans14 WITH (NOLOCK) 
		WHERE custid = @CustId
			AND refno = @RefNo
			AND matchid = 29
			AND bettype = 29
			AND transid NOT IN (SELECT TransId FROM @tmpBettrans)
	END

	IF @maxMatchdate > @MoveBetDay  --- get data from bettrans
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
				WHEN betcheck IS NULL THEN CONVERT(INT, hdp2)	-- old Parlay tickets
				ELSE CONVERT(INT, betcheck)						-- new Parlay tickets
			END AS Bitmap
		FROM dbo.bettrans WITH(NOLOCK) 
		WHERE custid = @CustId
			AND refno = @RefNo
			AND matchid = 29
			AND bettype = 29
			AND transid NOT IN (SELECT TransId FROM @tmpBettrans)
	END
	
	INSERT INTO @tmpResults (
		WinLostDate,
		Serial,
		Modds,
		Stake,
		WinLost,
		StatusId,
		PlayerComm )
	SELECT
		b.winlostdate,
		b.Serial,
		b.mOdds,
		b.stake,
		b.winlost,
		b.statusid,
		b.playercomm
	FROM dbo.BetParlayResult AS b WITH(NOLOCK) 
	WHERE b.RefNo = @RefNo AND b.Serial NOT IN (SELECT Serial FROM @tmpResults)

	-- Generate betParlayDetail
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
			bCnt = t.N
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
			INNER JOIN bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON b.MatchId = m.matchid
		WHERE p.StatusId NOT IN (0, 1, 113)
	END

	IF @MinMatchdate <= @MoveBetDay
	BEGIN
		INSERT INTO @tmpMatch
		SELECT
			p.serial,
			m.homeid,
			m.awayid
		FROM @tmpResults AS p
			INNER JOIN @betParlayDetail AS b ON p.Serial = b.Serial
			INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.MatchId = m.matchid
		WHERE p.StatusId NOT IN (0, 1, 113)
	END

	IF @MaxMatchdate > @MoveBetDay
	BEGIN
		INSERT INTO @tmpMatch
		SELECT
			p.serial,
			m.homeid,
			m.awayid
		FROM @tmpResults AS p
			INNER JOIN @betParlayDetail AS b ON p.Serial = b.Serial
			INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.MatchId = m.matchid
		WHERE p.StatusId NOT IN (0, 1, 113)
	END
	
	-- Calculate outstanding
	SELECT @Outstanding = MAX(stake)
	FROM @tmpBettrans

	SELECT @Outstanding = @Outstanding - ISNULL(SUM(stake), 0)
	FROM @tmpResults
	WHERE StatusId NOT IN (0, 1)

	-- Return combo detail
	SELECT DISTINCT
		WinLostDate,
		TransId,
		Serial,
		StatusId,
		CASE StatusId
			WHEN 101 THEN 'REJECT'
			WHEN 102 THEN 'VOID'
			WHEN 103 THEN 'REFUND'
			WHEN 111 THEN 'DRAW'
			WHEN 112 THEN 'WON' 
			ELSE '' 
		END AS status,
		Modds,
		Stake,
		WinLost - Stake AS winlost,
		PlayerComm
	FROM @tmpResults
	WHERE StatusId NOT IN (0, 1, 113)

	UNION ALL

	SELECT DISTINCT
		WinLostDate,
		0 AS transid,
		0 AS serial,
		113 AS statusid,
		'LOSE' AS status,
		0 AS modds,
		SUM(Stake) AS stake,
		SUM(WinLost - Stake) AS winlost,
		SUM(PlayerComm) AS playercomm
	FROM @tmpResults
	WHERE StatusId = 113
	GROUP BY WinLostDate 
	ORDER BY WinLostDate ASC

	SELECT * FROM @tmpMatch
END
GO





GRANT EXECUTE ON [dbo].[CS_BetList_Parlay_TicketDetail] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[CS_BetList_Parlay_TicketDetail] TO [bodbDownlineNetView]
GO
