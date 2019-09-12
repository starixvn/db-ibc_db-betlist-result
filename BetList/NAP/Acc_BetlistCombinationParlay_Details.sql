/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet,bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Acc_BetlistCombinationParlay_Details]
	@RefNo			BIGINT,
	@TransId		BIGINT		= 0,
	@BetId			BIGINT		= 0,
	@CustId			INT,
	@MoveBetDay		SMALLDATETIME,
	@BalanceUpDay	SMALLDATETIME,
	@Outstanding	MONEY		= 0 OUTPUT
AS

/*
	Created by: 20110802@Johnson
	Task: Get details info for Combination Mix Parlay
	DB: DBACC.BODB02
	Original:
	
	Revisions:
		- 20110808@Sophia: Add permission [bodbDownlineNet] for Agent site call this sp
		- 20110809@Sophia: Add Playercomm
		- 20110826@Jamie: Result Archive
		- 20111202@Johnson: Correct outstanding
		- 20120229@Lukas: Fix bug in case of sub & main ticket are not in the same table (bettrans14, bettrans_bk,..)
		- 20130121@Dan: change linked server DB06 to DBARC
		- 20130404@Daniel (on live version) : fix bug check movebet day in case movebetday = min(matchdate)
		- 20151210@Kos: Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]
		- 20160408@Kos: Support Combo Parlay [#Redmine: 55282]
		- 20161010@Kos: Add product bet type range for sub tickets [Redmine: #65045]
		- 20170210@Kos: Add DISTINCT to prevent duplicate ticket detail [Redmine: #71007]
		- 20170801@Kos: Return TransId instead of 0 [Redmine: #73545]
		- 20190912@Kos: Show LOSE combination details [Redmine: #117888]
					- Remove param @Language
					- Move from DBAGE.bodb02 to DBACC.bodb02
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
		MatchDate	SMALLDATETIME,
		--for generating combination parlays
		RN			TINYINT,	-- set No. for selection in the combination
		Cnt			TINYINT,	-- total selection count, base on bettransm/14
		bCnt		TINYINT		-- total selection count, stored in bettrans
	)

	DECLARE @tmpResults TABLE (
		WinLostDate SMALLDATETIME,
		TransId		BIGINT,
		Serial		BIGINT,
		StatusId	TINYINT,
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
	DECLARE @tmpMatch AS TABLE (
		Serial	BIGINT,
		HomeId	INT,
		AwayId	INT
	)

	DECLARE @minMatchdate SMALLDATETIME,
			@maxMatchdate SMALLDATETIME

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

	SELECT	@minMatchdate = MIN(matchdate),
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
		FROM bodb_Archive.dbo.bettrans_bk AS b WITH(NOLOCK) 
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
			b.winlostdate,
			b.Serial,
			b.mOdds,
			b.stake,
			b.winlost,
			b.statusid,
			b.playercomm
		FROM bodb_Archive.dbo.betparlayresult AS b WITH (NOLOCK)
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
		FROM dbo.bettrans14 AS b WITH(NOLOCK) 
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
		FROM dbo.bettrans AS b WITH(NOLOCK) 
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
		WHERE p.StatusId NOT IN (0, 1)
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
		WHERE p.StatusId NOT IN (0, 1)
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
		WHERE p.StatusId NOT IN (0, 1)
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
			WHEN 113 THEN 'LOSE'
			ELSE '' 
		END AS status,
		Modds,
		Stake,
		WinLost - Stake AS winlost,
		PlayerComm
	FROM @tmpResults
	WHERE StatusId NOT IN (0, 1)
	ORDER BY WinLostDate ASC

	SELECT * FROM @tmpMatch
END
GO



GRANT EXECUTE ON [dbo].[Acc_BetlistCombinationParlay_Details] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Acc_BetlistCombinationParlay_Details] TO [bodbDownlineNetView]
GO
GRANT EXECUTE ON [dbo].[Acc_BetlistCombinationParlay_Details] TO [bodbAdminNet]
GO
