ALTER PROCEDURE [dbo].[Acc_BetlistCombinationParlay_ByTransID]
	@transid		BIGINT,
	@custid			INT,
	@MoveBetDay		DATETIME,
	@BalanceUpDay	DATETIME
AS

/*
	Created: Johnson
	Date:28Nov2011
	Task: Get details of parlay tickets
	DB: DBAGE.BODB02
	
	Revisions:
		- 20111215@Lukas: correct scomm, acomm, comm
		- 20111229@Jim : remove function :f_GetChoice
		- 20120220@Johnson: support view old data
		- 20120228@Lukas: Get full data of system parlay (related ticket)
		- 20120419@Lukas: Show transid of main ticket for subticket of system parlay
		- 20120927@Johnson: get commstatus column to check double comm losing
		- 20130121@Dan: change linked server DB06 to DBARC
		- 20130514@Elodie: Get odds value
		- 20131216@Kathy: Get data from bettrans14 if @minMatchdate = @MoveBetDay
		- 20141013@Sophia: Get betcheck of bettransm for Sportting Solution
		- 20151210@Kos: Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]
		- 20160120@Kos: Add transdesc to support PH All In One 1.2 new bet types [#Redmine: 50897]

	Paramters Explanation:
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @refno			BIGINT,
			@minMatchdate	DATETIME,
			@maxMatchdate	DATETIME

	--- check if @transid in bettrans
	SELECT @refno = refno
	FROM dbo.bettrans WITH (NOLOCK)
	WHERE transid = @transid 
		AND custid = @custid 
		AND bettype = 29

	IF @refno IS NULL 
	BEGIN
		SELECT @refno = refno
		FROM dbo.bettrans14 WITH (NOLOCK)
		WHERE transid = @transid 
			AND custid = @custid 
			AND bettype = 29
	END
	
	IF @refno IS NULL
	BEGIN
		SELECT @refno = refno
		FROM DBARC.BODB_Archive.dbo.bettrans_BK WITH (NOLOCK)
		WHERE transid = @transid 
			AND custid = @custid 
			AND bettype = 29
	END

	DECLARE @tmpBettrans AS TABLE(
		transid			BIGINT,
		betid			BIGINT,
		transdate		DATETIME,
		refno			BIGINT, 
		winlostdate		SMALLDATETIME,
		odds			MONEY,
		modds			MONEY,
		stake			MONEY, 
		actual_stake	MONEY, 
		winlost			MONEY, 
		playercomm		MONEY,
		status			VARCHAR(20),
		comstatus		NVARCHAR(20),
		betteam			VARCHAR(20), 
		IP				VARCHAR(40), 
		spositiontaking	SMALLMONEY, 
		mpositiontaking	SMALLMONEY, 
		apositiontaking	SMALLMONEY, 
		swinlost		MONEY, 
		mwinlost		MONEY, 
		awinlost		MONEY, 
		sdiscount		SMALLMONEY, 
		adiscount		SMALLMONEY, 
		discount		SMALLMONEY, 
		scomm			MONEY, 
		acomm			MONEY, 
		comm			MONEY,
		--for generating combination parlays if not in BetParlayResult
		[N]			[tinyint] , -- total selection (match)
		[cnt]		[smallint] , -- total sub-ticket count
		[bitmap]	[smallint] -- bitmap to identify which parlay set is choosen
	)

	DECLARE @parlay_base AS TABLE (
		transid			BIGINT,
		refno			BIGINT,
		winlostdate		SMALLDATETIME,
		bettype			INT,
		homeid			INT,
		awayid			INT,
		hdp1			SMALLMONEY,
		hdp2			SMALLMONEY,
		odds			MONEY,
		betteam			VARCHAR(20),
		statusid		INT,
		livehomescore	INT,
		liveawayscore	INT,
		liveindicator	BIT,
		leagueid		INT,
		sporttype		INT,
		isNeutral		BIT,
		matchid			INT,
		matchcode		VARCHAR(50),
		matchdate		DATETIME,
		Betcheck		NVARCHAR(50),
		transdesc		NVARCHAR(200),
		--for generating combination parlays
		RN		TINYINT, -- set No. for selection in the combination
		CNT		TINYINT, -- total selection count, base on bettransm/14
		bCNT	TINYINT -- total selection count, stored in bettrans
	)

	DECLARE @tmpResults AS TABLE(
		winlostdate	DATETIME,
		serial		BIGINT,
		modds		MONEY,
		stake		MONEY,
		winlost		MONEY,
		statusid	INT,
		status		VARCHAR(20)
	)

	DECLARE @betParlayDetail TABLE (
		RefNo	BIGINT, 
		Serial	INT,
		matchid	INT
	)

	DECLARE @tmpMatch AS TABLE(
		serial	BIGINT,
		homeid	INT,
		awayid	INT
	)

	INSERT INTO @parlay_base (
		transid,
		refno,
		winlostdate,
		bettype,
		homeid,
		awayid,
		hdp1,
		hdp2,
		odds,
		betteam,
		statusid,
		livehomescore,
		liveawayscore,
		liveindicator,
		leagueid,
		sporttype,
		isNeutral,
		matchid,
		matchcode,
		matchdate,
		Betcheck,
		transdesc)
	SELECT
		bm.transid, 
		bm.refno, 
		bm.winlostdate,
		bm.bettype,
		m.homeid, 
		m.awayid, 
		bm.hdp1, 
		bm.hdp2, 
		bm.odds, 
		bm.betteam,
		bm.statusid, 
		bm.livehomescore, 
		bm.liveawayscore, 
		bm.liveindicator, 
		m.leagueid, 
		m.sporttype, 
		m.isNeutral,
		m.matchid,
		m.matchcode, 
		bm.matchdate, 
		ISNULL(bm.Betcheck, '') AS BetCheck,
		ISNULL(bm.transdesc, '') AS transdesc
	FROM dbo.bettransm AS bm WITH (NOLOCK)
		INNER JOIN dbo.match AS m WITH (NOLOCK) ON bm.matchid = m.matchid
	WHERE refno = @refno AND custid = @custid

	UNION

	SELECT
		bm.transid, 
		bm.refno, 
		bm.winlostdate,
		bm.bettype,
		m.homeid, 
		m.awayid, 
		bm.hdp1, 
		bm.hdp2, 
		bm.odds, 
		bm.betteam,
		bm.statusid, 
		bm.livehomescore, 
		bm.liveawayscore, 
		bm.liveindicator, 
		m.leagueid, 
		m.sporttype, 
		m.isNeutral,
		m.matchid,
		m.matchcode, 
		bm.matchdate, 
		ISNULL(bm.Betcheck, '') AS BetCheck,
		ISNULL(bm.transdesc, '') AS transdesc
	FROM dbo.bettransm14 AS bm WITH (NOLOCK)
		INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON bm.matchid = m.matchid
	WHERE refno = @refno
	
	UNION 
	
	SELECT
		bm.transid, 
		bm.refno, 
		bm.winlostdate,
		bm.bettype,
		m.homeid,
		m.awayid,
		bm.hdp1,
		bm.hdp2,
		bm.odds,
		bm.betteam,
		bm.statusid,
		bm.livehomescore,
		bm.liveawayscore,
		bm.liveindicator,
		m.leagueid,
		m.sporttype,
		m.isNeutral,
		m.matchid,
		m.matchcode,
		bm.matchdate,
		ISNULL(bm.Betcheck, '') AS BetCheck,
		ISNULL(bm.transdesc, '') AS transdesc
	FROM DBARC.bodb_archive.dbo.bettransm AS bm WITH (NOLOCK)
		INNER JOIN DBARC.bodb_archive.dbo.match_bk AS m WITH (NOLOCK) ON bm.matchid = m.matchid
	WHERE refno = @refno

	SELECT	@minMatchdate = MIN(matchdate),
			@maxMatchdate = MAX(matchdate)
	FROM @parlay_base

	IF @minMatchDate < @BalanceUpDay  --- get data from bettrans_bk
	BEGIN
		INSERT INTO @tmpBettrans (
			transid,
			betid, 
			transdate, 
			refno, 
			winlostdate, 
			odds, 
			modds, 
			stake, 
			actual_stake, 
			winlost, 
			playercomm, 
			status, 
			comstatus, 
			betteam, 
			ip, 
			spositiontaking,
			mpositiontaking, 
			apositiontaking, 
			swinlost,
			mwinlost, 
			awinlost,
			sdiscount, 
			adiscount, 
			discount, 
			scomm, 
			acomm, 
			comm, 
			N, 
			cnt, 
			bitmap)
		SELECT
			transid,
			betid,
			transdate,
			refno,
			winlostdate,
			odds,
			modds,
			stake,
			actual_stake,
			CASE WHEN statusid NOT IN (0,1) THEN winlost - actual_stake ELSE winlost END AS winlost,
			playercomm,
			status,
			CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
			betteam,
			ip,
			spositiontaking,
			mpositiontaking,
			apositiontaking,
			swinlost,
			mwinlost,
			awinlost,
			sdiscount,
			adiscount,
			discount,
			scomm - acomm,
			acomm - comm,
			comm - playercomm,
			len(betteam) AS N,
			hdp1 AS cnt,
			hdp2 AS bitmap
		FROM DBARC.bodb_archive.dbo.bettrans_bk AS b WITH(NOLOCK) 
		WHERE custid = @custid 
			AND refno = @refno 
			AND matchid = 29 
			AND bettype = 29
			AND transid NOT IN (SELECT transid FROM @tmpBettrans)
		
		INSERT INTO @tmpResults(
			winlostdate, 
			serial, 
			modds, 
			stake, 
			winlost, 
			statusid)
		SELECT 
			winlostdate, 
			serial, 
			modds, 
			stake, 
			winlost, 
			statusid
		FROM DBARC.bodb_archive.dbo.betparlayresult AS b WITH(NOLOCK) 
		WHERE refno = @refno
	END

	IF @minMatchdate <= @MoveBetDay  --- get data from bettrans14
	BEGIN
		INSERT INTO @tmpBettrans (
			transid,
			betid, 
			transdate, 
			refno, 
			winlostdate, 
			odds, 
			modds, 
			stake, 
			actual_stake, 
			winlost,
			playercomm,
			status,
			comstatus,
			betteam,
			ip,
			spositiontaking,
			mpositiontaking, 
			apositiontaking, 
			swinlost,
			mwinlost,
			awinlost,
			sdiscount,
			adiscount,
			discount,
			scomm,
			acomm,
			comm,
			N,
			cnt,
			bitmap)
		SELECT
			transid,
			betid,
			transdate,
			refno,
			winlostdate,
			odds,
			modds,
			stake,
			actual_stake,
			CASE WHEN statusid NOT IN (0,1) THEN winlost - actual_stake ELSE winlost END AS winlost,
			playercomm,
			status,
			CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,  
			betteam,
			ip,
			spositiontaking,
			mpositiontaking,
			apositiontaking,
			swinlost,
			mwinlost,
			awinlost,
			sdiscount,
			adiscount,
			discount,
			scomm - acomm,
			acomm - comm,
			comm - playercomm,
			len(betteam) AS N,
			hdp1 AS cnt,
			hdp2 AS bitmap
		FROM dbo.bettrans14 AS b WITH(NOLOCK) 
		WHERE custid = @custid 
			AND refno = @refno 
			AND matchid = 29 
			AND bettype = 29
			AND transid NOT IN (SELECT transid FROM @tmpBettrans)
	END

	IF @maxMatchdate > @MoveBetDay  --- get data from bettrans
	BEGIN
		INSERT INTO @tmpBettrans (
			transid,
			betid,
			transdate,
			refno,
			winlostdate,
			odds,
			modds,
			stake,
			actual_stake,
			winlost,
			playercomm,
			status,
			comstatus,
			betteam,
			ip,
			spositiontaking,
			mpositiontaking,
			apositiontaking,
			swinlost,
			mwinlost,
			awinlost,
			sdiscount,
			adiscount,
			discount,
			scomm,
			acomm,
			comm,
			N,
			cnt,
			bitmap)
		SELECT
			transid,
			betid,
			transdate,
			refno,
			winlostdate,
			odds,
			modds,
			stake,
			actual_stake,
			winlost - actual_stake AS winlost,
			playercomm,
			status,
			CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,  
			betteam,		
			ip,
			spositiontaking,
			mpositiontaking,
			apositiontaking,
			swinlost,
			mwinlost,
			awinlost,
			sdiscount,
			adiscount,
			discount,
			scomm - acomm,
			acomm - comm,
			comm - playercomm,
			len(betteam) AS N,
			hdp1 AS cnt,
			hdp2 AS bitmap
		FROM dbo.bettrans AS b WITH(NOLOCK) 
		WHERE custid = @custid 
			AND refno = @refno 
			AND matchid = 29 
			AND bettype = 29
			AND transid NOT IN (SELECT transid FROM @tmpBettrans)
	END
	
	INSERT INTO @tmpResults(
		winlostdate, 
		serial, 
		modds, 
		stake, 
		winlost, 
		statusid)
	SELECT 
		winlostdate, 
		serial, 
		modds, 
		stake, 
		winlost, 
		statusid
	FROM dbo.betparlayresult AS b WITH (NOLOCK) 
	WHERE refno = @refno AND serial NOT IN (SELECT serial FROM @tmpResults)

	IF NOT EXISTS (SELECT TOP 1 1 FROM @tmpResults)
	BEGIN
		DECLARE @betParlayResult TABLE  (
			RefNo		BIGINT, 
			Serial		INT, 
			winlostdate SMALLDATETIME,
			statusid	TINYINT, 
			stake		MONEY, 
			Odds		MONEY, 
			mOdds		MONEY, 
			winlost		MONEY
		)

		;WITH sub AS (SELECT ROW_NUMBER() OVER (ORDER BY matchid) RN, matchid FROM @parlay_base)
		UPDATE pb
		SET RN = sub.RN
		FROM sub
			INNER JOIN @parlay_base pb ON sub.matchid = pb.matchid

		-- prepare N
		;WITH sub AS (SELECT COUNT(*) cnt FROM @parlay_base)
		UPDATE pb
		SET CNT = sub.cnt, 
			bCNT = t.N
		FROM sub , @parlay_base pb , @tmpBettrans t

		IF NOT EXISTS(SELECT 1 FROM @parlay_base WHERE cnt <> bCnt)
		BEGIN
			INSERT INTO @betParlayDetail
			SELECT 
				pb.RefNo, 
				rc.Serial, 
				matchid
			FROM
				@parlay_base AS pb
				INNER JOIN @tmpBettrans AS tb ON pb.refno = tb.refno
				INNER JOIN dbo.RefCombination AS rc WITH (NOLOCK) ON pb.RN = rc.seq AND pb.CNT = rc.N AND (tb.bitmap & rc.bitmap) > 0

			INSERT INTO @betParlayResult
			SELECT DISTINCT 
				tb.RefNo, 
				rc.Serial, 
				tb.winlostdate, 
				0, 
				tb.stake/tb.cnt, 
				0,
				0, 
				0
			FROM
				@tmpBettrans tb
				INNER JOIN dbo.RefCombination rc WITH (NOLOCK) ON tb.N = rc.N AND (tb.bitmap&rc.bitmap) > 0	

			INSERT INTO @tmpResults
			SELECT 
				winlostdate,
				serial,
				modds,
				stake,
				winlost,
				statusid,
				'running' AS status
			FROM @betParlayResult
			WHERE refno = (SELECT refno FROM @tmpBettrans WHERE transid = @transid)
			
			INSERT INTO @tmpMatch
			SELECT
				p.serial,
				homeid,
				awayid
			FROM @tmpResults p 
				INNER JOIN @betParlayDetail b ON b.RefNo = (SELECT refno FROM @tmpBettrans WHERE transid = @transid) AND p.Serial = b.Serial
				INNER JOIN dbo.match m WITH (NOLOCK) ON b.matchid = m.matchid	
		END
	END
	ELSE
	BEGIN
		----- generate betparlay detail
		;WITH sub AS 
		(
			SELECT ROW_NUMBER() OVER (ORDER BY matchid) RN, matchid FROM @parlay_base
		)
		UPDATE pb
		SET RN = sub.RN
		FROM sub
			INNER JOIN @parlay_base pb ON sub.matchid = pb.matchid

		-- prepare N
		;WITH sub AS (SELECT COUNT(*) cnt FROM @parlay_base)
		UPDATE pb
		SET CNT = sub.cnt, 
			bCNT = t.N
		FROM sub, @parlay_base pb , @tmpBettrans t
		
		IF NOT EXISTS(SELECT 1 FROM @parlay_base WHERE cnt <> bCnt)
		BEGIN
			INSERT INTO @betParlayDetail
			SELECT 
				pb.RefNo, 
				rc.Serial, 
				matchid
			FROM
				@parlay_base AS pb
				INNER JOIN @tmpBettrans AS tb ON pb.refno = tb.refno
				INNER JOIN dbo.RefCombination AS rc WITH (NOLOCK) ON pb.RN = rc.seq AND pb.CNT = rc.N AND (tb.bitmap&rc.bitmap) > 0
		END

		----- get homeid, awayid
		IF @MinMatchdate < @BalanceUpday
		BEGIN
			INSERT INTO @tmpMatch
			SELECT
				p.serial,
				homeid,
				awayid
			FROM @tmpResults AS p 
				INNER JOIN @betParlayDetail AS b ON p.Serial = b.Serial
				INNER JOIN DBARC.BODB_Archive.dbo.match_bk AS m WITH (NOLOCK) ON b.matchid = m.matchid
		END

		IF @MinMatchdate <= @MoveBetDay
		BEGIN
			INSERT INTO @tmpMatch
			SELECT
				p.serial,
				homeid,
				awayid
			FROM @tmpResults AS p 
				INNER JOIN @betParlayDetail AS b ON p.Serial = b.Serial
				INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
		END

		IF @MaxMatchdate > @MoveBetDay
		BEGIN
			INSERT INTO @tmpMatch
			SELECT
				p.serial,
				homeid,
				awayid
			FROM @tmpResults AS p 
				INNER JOIN @betParlayDetail AS b ON p.Serial = b.Serial
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
		END
	END

	SELECT
		CASE WHEN ISNULL(betid,0) = 0 THEN transid ELSE betid END AS transid,
		transdate,
		refno,
		winlostdate,
		odds,
		modds,
		stake,
		actual_stake,
		winlost,
		playercomm,
		status,
		comstatus,
		betteam,
		ip,
		spositiontaking,
		mpositiontaking,
		apositiontaking,
		swinlost,
		mwinlost,
		awinlost,
		sdiscount,
		adiscount,
		discount,
		scomm,
		acomm,
		comm
	FROM @tmpBettrans b

	SELECT
		transid, 
		refno,
		winlostdate,
		bettype,
		homeid,
		awayid,
		hdp1, 
		hdp2, 
		odds, 
		betteam,
		statusid,
		livehomescore, 
		liveawayscore, 
		liveindicator, 
		leagueid,
		sporttype,
		IsNeutral,
		matchid,
		matchcode, 
		BetCheck,
		transdesc
	FROM @Parlay_Base
	
	SELECT 
		winlostdate,
		serial,
		modds,
		stake,
		statusid,
		CASE WHEN statusid NOT IN (0,1) THEN winlost - stake ELSE winlost END AS winlost,
		CASE statusid 
			WHEN 101 THEN 'REJECT'
			WHEN 102 THEN 'VOID'
			WHEN 103 THEN 'REFUND'
			WHEN 111 THEN 'DRAW'
			WHEN 112 THEN 'WON'
			WHEN 113 THEN 'LOSE' 
			WHEN 0 THEN 'RUNNING' 
			ELSE '' 
		END AS status
	FROM @tmpResults
	ORDER BY CASE WHEN statusid NOT IN (0,1) THEN winlostdate ELSE '' END ASC

	SELECT * FROM @tmpMatch
END



GO
GRANT VIEW DEFINITION ON [dbo].[Acc_BetlistCombinationParlay_ByTransID] TO [vnteam]
GO
GRANT EXECUTE ON [dbo].[Acc_BetlistCombinationParlay_ByTransID] TO [bodbAdminNet]