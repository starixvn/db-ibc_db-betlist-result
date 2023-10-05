/*<info serverAlias="DBSIG-bodb02" executers="bodbAdminNet,bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[SiteDB_Acc_BetList_SelCombinationParlayDetail]
	@RefNo			BIGINT,
	@CustId			INT,
	@MoveBetDay		SMALLDATETIME,
	@BalanceUpDay	SMALLDATETIME,
	@Outstanding	MONEY		= 0 OUTPUT,
	@IsParlayBoost	BIT			= 0 OUTPUT
AS

/*
	Created by: 20220727@Kos
	Task: NAP - Bet List - Details link of Mix Parlay/System Parlay ticket
	DB: DBSIG.BODB02

	Revisions:
		- 20220727@Kos: Scale out DBTRANS [Redmine: #175297]
		- 20231004@Kos: Support Parlay Boost [Redmine: #194992]
					- Add output param @IsParlayBoost BIT
					- Return additional columns Odds MONEY, ExtraValue MONEY
					- Remove param @TransId, @BetId
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

	DECLARE @tmpBettrans AS TABLE (
		TransId			BIGINT,
		RefNo			BIGINT,
		OddsSpread		MONEY,
		BetTeam			NVARCHAR(10),
		Status			NVARCHAR(10),
		Stake			MONEY,
		Actual_Stake	MONEY,
		WinLost			MONEY,
		ExtraInfo		VARCHAR(1000),
		--for generating combination parlays if not in BetParlayResult
		N				TINYINT,	-- Number of selection
		Bitmap			INT,			-- Combination Bitmap
		WhTicket		TINYINT
	)

	DECLARE @parlay_base AS TABLE (
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
		Odds		MONEY,
		Modds		MONEY,
		Stake		MONEY,
		WinLost		MONEY,
		PlayerComm	MONEY,
		ExtraValue	MONEY
	)

	DECLARE @betParlayDetail TABLE (
		RefNo	BIGINT,
		Serial	INT,
		MatchId	INT
	)
	DECLARE @tmpMatch AS TABLE (
		Serial		BIGINT,
		HomeId		INT,
		AwayId		INT,
		IsNeutral	BIT
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
	FROM DBARC.bodb_Archive.dbo.bettransm AS bm WITH (NOLOCK)
		INNER JOIN DBARC.bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON bm.matchid = m.matchid
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
			oddsspread,
			betteam,
			status,
			stake,
			actual_stake,
			winlost,
			ISNULL(ExtraInfo, '') AS ExtraInfo,
			CASE
				WHEN betcheck IS NULL THEN LEN(betteam)		-- old Parlay tickets
				ELSE hdp2									-- new Parlay tickets
			END AS N,
			CASE
				WHEN betcheck IS NULL THEN CONVERT(INT, hdp2)	-- old Parlay tickets
				ELSE CONVERT(INT, betcheck)						-- new Parlay tickets
			END AS Bitmap,
			3 AS WhTicket
		FROM DBARC.bodb_Archive.dbo.bettrans_bk WITH(NOLOCK) 
		WHERE custid = @CustId
			AND refno = @RefNo
			AND matchid = 29
			AND bettype = 29
			AND transid NOT IN (SELECT transid FROM @tmpBettrans)

		INSERT INTO @tmpResults (
			WinLostDate,
			Serial,
			Odds,
			Modds,
			Stake,
			WinLost,
			StatusId,
			PlayerComm,
			ExtraValue )
		SELECT
			winlostdate,
			Serial,
			Odds,
			mOdds,
			stake,
			winlost,
			statusid,
			playercomm,
			ExtraValue
		FROM DBARC.bodb_Archive.dbo.betparlayresult WITH (NOLOCK)
		WHERE refno = @RefNo
	END

	IF @minMatchdate <= @MoveBetDay		--- bettrans14 range
	BEGIN
		INSERT INTO @tmpBettrans
		SELECT
			transid,
			refno,
			oddsspread,
			betteam,
			status,
			stake,
			actual_stake,
			winlost,
			ISNULL(ExtraInfo, '') AS ExtraInfo,
			CASE
				WHEN betcheck IS NULL THEN LEN(betteam)		-- old Parlay tickets
				ELSE hdp2									-- new Parlay tickets
			END AS N,
			CASE
				WHEN betcheck IS NULL THEN CONVERT(INT, hdp2)	-- old Parlay tickets
				ELSE CONVERT(INT, betcheck)						-- new Parlay tickets
			END AS Bitmap,
			2 AS WhTicket
		FROM dbo.bettrans14 WITH(NOLOCK) 
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
			oddsspread,
			betteam,
			status,
			stake,
			actual_stake,
			winlost,
			ISNULL(ExtraInfo, '') AS ExtraInfo,
			CASE
				WHEN betcheck IS NULL THEN LEN(betteam)		-- old Parlay tickets
				ELSE hdp2									-- new Parlay tickets
			END AS N,
			CASE
				WHEN betcheck IS NULL THEN CONVERT(INT, hdp2)	-- old Parlay tickets
				ELSE CONVERT(INT, betcheck)						-- new Parlay tickets
			END AS Bitmap,
			1 AS WhTicket
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
		Odds,
		Modds,
		Stake,
		WinLost,
		StatusId,
		PlayerComm, 
		ExtraValue )
	SELECT
		winlostdate,
		Serial,
		Odds,
		mOdds,
		stake,
		winlost,
		statusid,
		playercomm,
		ExtraValue
	FROM dbo.BetParlayResult AS b WITH(NOLOCK) 
	WHERE RefNo = @RefNo
		AND Serial NOT IN (SELECT Serial FROM @tmpResults)

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
			m.awayid,
			m.IsNeutral
		FROM @tmpResults AS p
			INNER JOIN @betParlayDetail AS b ON p.Serial = b.Serial
			INNER JOIN DBARC.bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON b.MatchId = m.matchid
		WHERE p.StatusId NOT IN (0, 1)
	END

	IF @MinMatchdate <= @MoveBetDay
	BEGIN
		INSERT INTO @tmpMatch
		SELECT
			p.serial,
			m.homeid,
			m.awayid,
			m.IsNeutral
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
			m.awayid,
			m.IsNeutral
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

	DECLARE
		@Actual_Stake	MONEY,
		@WinLost		MONEY,
		@Discount		MONEY,
		@OriginalOdds	MONEY,
		@BetTeam		NVARCHAR(10),
		@Status			NVARCHAR(10)

	SELECT
		@Actual_Stake = Actual_Stake,
		@WinLost = WinLost,
		@Discount = CASE
						WHEN ExtraInfo LIKE '%p1%' THEN
							ISNULL(CAST(('<xml>' + ExtraInfo + '</xml>') AS XML).value('data(/xml/p1/@d)[1]','MONEY'), 0)
						ELSE 0
					END,
		@BetTeam = BetTeam,
		@Status = Status,
		@IsParlayBoost = CASE
							WHEN BetTeam = '1'
								AND OddsSpread = 2
								AND Status = 'Won'
								AND ISNULL(CAST(('<xml>' + ExtraInfo + '</xml>') AS XML).value('data(/xml/p1/@bba)[1]','MONEY'), 0) > 0 THEN 1
							ELSE 0
						END
	FROM @tmpBettrans

	-- Get original odds for Mix Parlay
	IF @BetTeam = '1'
	BEGIN
		IF @Status IN ('Running', 'Waiting')
		BEGIN
			IF EXISTS (SELECT 1 FROM dbo.BetParlayDetail WHERE RefNo = @RefNo)
			BEGIN
				SELECT @OriginalOdds = dbo.PRODUCT(odds)
				FROM dbo.BetParlayDetail WITH (NOLOCK)
				WHERE RefNo = @RefNo
				GROUP BY RefNo
			END
			ELSE
			BEGIN
				SELECT @OriginalOdds = dbo.PRODUCT(odds)
				FROM dbo.bettransm WITH (NOLOCK)
				WHERE RefNo = @RefNo
				GROUP BY RefNo
			END
		END
	END

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
		CASE
			WHEN @Status IN ('Running', 'Waiting') THEN @OriginalOdds
			ELSE Odds
		END AS Odds,
		CASE
			WHEN @BetTeam = '1' AND StatusId = 113 AND MOdds = 0 THEN Odds
			ELSE MOdds
		END AS Modds,
		Stake,
		CASE
			WHEN @Discount > 0 THEN @WinLost - @Actual_Stake
			ELSE WinLost - Stake
		END AS WinLost,
		PlayerComm,
		ExtraValue
	FROM @tmpResults
	WHERE StatusId NOT IN (0, 1)
	ORDER BY WinLostDate ASC

	SELECT DISTINCT * FROM @tmpMatch
END
GO