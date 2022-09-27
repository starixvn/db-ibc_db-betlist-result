/*<info serverAlias="DBACC-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_BetList_SelCombinationParlayDetail]
	@AgentList		VARCHAR(MAX),
	@RefNo			BIGINT,
	@MoveBetsDay	SMALLDATETIME,
	@BalanceUpDay	SMALLDATETIME,
	@BaseCurrency	VARCHAR(12)	= '',
	@Outstanding	MONEY		= 0 OUTPUT
AS

/*
	Created: Henry@20110802
	Task: Get combination mix parlay tickets
	DB: DBACC.bodb02
	Revisions:
		- 20111202@Henry: correct outstanding
		- 20120214@Jim: change to use  table ExchangeDaily by use function Lrf_f_GetExchangeDaily
		- 20120319@Henry: Fix bug in case of sub & main ticket are not in the same table (bettrans14, bettrans_bk,..)
		- 20120724@Jim: add player commission value
		- 20130404@Daniel: fix bug check movebet day in case movebetday = min(matchdate)
		- 20130514@Jim:Restrict permission of Licensee Users by currency
		- 20150123@Jim: support base on Currency GBP
		- 20151203@Kos: Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]
		- 20160202@Kos: Support PH All In One 1.2 [#Redmine: 50897]
		- 20160414@Kos: Support Combo Parlay [#Redmine: 55282]
		- 20160510@Kos: Remove param @TransId, @BetId, @CustId [#Redmine: 55282]
		- 20161007@Kos: Add product bet type range for sub tickets [Redmine: #65045]
		- 20170307@Kos: Support sub licensees [#Redmine: 71679]
		- 20180719@Kos: Support more base currencies [#Redmine: 80941]
		- 20190426@Kos: Support base currency INH [Redmine: #112603]
		- 20191011@Kos: Show LOSE combination details [Redmine: #117888]
					- Move from DBEXT.bodb02 to DBACC.bodb02
					- Don't return column Order, TransId anymore
		- 20191115@Kos: Show (N) for neutral match [Redmine: #123772]
		- 20201123@Kos: Support God Of Fortune [Redmine: #145834]
		- 20210301@Kos: Add BDT and INR as base currencies [Redmine: 150375]
		- 20230922@Kos: Support crypto currency [Redmine: 177481]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @TempAg TABLE (CustId INT, Currency INT)

	-- Get AgentList
	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT, @AgentList
	
		INSERT INTO @TempAg (CustId, Currency)
		SELECT AgentId, Currency
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId INT, Currency INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY
	BEGIN CATCH
		SELECT ErrCode = 100,
			ErrMsg = N'Parameter invalid.'

		RETURN
	END CATCH

	-- Get Sport Bettype Matrix
	DECLARE @SportBettype TABLE(ProductId TINYINT, Bettype SMALLINT, EventType TINYINT)

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype
	SELECT ProductID, BetType, EventType
	FROM dbo.f_SportBettypeMatrix_Sel (1, 0, 0, 2, '', '', @IsTest)

	DECLARE @CustId	INT,
		@Currency	INT

	DECLARE @tmpBettrans AS TABLE (
		TransId			BIGINT,
		RefNo			BIGINT,
		Stake			MONEY,
		Actual_Stake	MONEY,
		WinLost			MONEY,
		ExtraInfo		VARCHAR(1000),
		--for generating combination parlays if not in BetParlayResult
		N				TINYINT,	-- Number of selection
		Bitmap			INT	-- Combination Bitmap
	)

	DECLARE @parlay_base AS TABLE (
		TransId			BIGINT,
		RefNo			BIGINT,
		CustId			INT,
		MatchId			INT,
		MatchDate		SMALLDATETIME,
		--for generating combination parlays
		RN				TINYINT,	-- set No. for selection in the combination
		Cnt				TINYINT,	-- total selection count, base on bettransm/14
		bCnt			TINYINT		-- total selection count, stored in bettrans
	)

	DECLARE @tmpResults TABLE (
		WinLostDate	SMALLDATETIME,
		Serial		BIGINT,
		StatusId	TINYINT,
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
		CustId,
		MatchId,
		MatchDate )
	SELECT
		bm.transid,
		bm.refno,
		bm.custid,
		m.matchid,
		bm.matchdate
	FROM dbo.bettransm AS bm WITH (NOLOCK)
		INNER JOIN dbo.match AS m WITH (NOLOCK) ON bm.matchid = m.matchid
		INNER JOIN @SportBettype AS sbt ON bm.bettype = sbt.Bettype
	WHERE bm.refno = @RefNo

	UNION

	SELECT
		bm.transid,
		bm.refno,
		bm.custid,
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
		bm.custid,
		m.matchid,
		bm.matchdate
	FROM bodb_Archive.dbo.bettransm AS bm WITH (NOLOCK)
		INNER JOIN bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON bm.matchid = m.matchid
		INNER JOIN @SportBettype AS sbt ON bm.bettype = sbt.Bettype
	WHERE bm.refno = @RefNo

	SELECT	@minMatchdate = MIN(matchdate),
			@maxMatchdate = MAX(matchdate)
	FROM @parlay_base

	SELECT TOP 1 @CustId = CustId
	FROM @parlay_base

	SELECT @Currency = currency
	FROM dbo.custinfo WITH (NOLOCK)
	WHERE custid = @CustId
		AND currency IN (SELECT DISTINCT Currency FROM @TempAg)

	-- Get bettrans and BetParlayResult data
	IF @minMatchdate < @BalanceUpDay
	BEGIN
		INSERT INTO @tmpBettrans
		SELECT
			transid,
			refno,
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
			END AS Bitmap
		FROM bodb_Archive.dbo.bettrans_bk WITH (NOLOCK)
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
		FROM bodb_Archive.dbo.BetParlayResult AS b WITH (NOLOCK)
		WHERE refno = @RefNo
	END

	IF @minMatchdate <= @MoveBetsDay	--- bettrans14 range
	BEGIN
		INSERT INTO @tmpBettrans
		SELECT
			transid,
			refno,
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
			END AS Bitmap
		FROM dbo.bettrans14 WITH (NOLOCK)
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
			END AS Bitmap
		FROM dbo.bettrans WITH (NOLOCK)
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
			m.awayid,
			m.IsNeutral
		FROM @tmpResults AS p
			INNER JOIN @betParlayDetail AS b ON p.Serial = b.Serial
			INNER JOIN bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON b.MatchId = m.matchid
		WHERE p.statusid NOT IN (0, 1)
	END

	IF @MinMatchdate <= @MoveBetsDay
	BEGIN
		INSERT INTO @tmpMatch
		SELECT
			p.serial,
			m.homeid,
			m.awayid,
			m.IsNeutral
		FROM @tmpResults AS p
			INNER JOIN @betParlayDetail AS b ON p.Serial = b.Serial
			INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
		WHERE p.statusid NOT IN (0, 1)
	END

	IF @MaxMatchdate > @MoveBetsDay
	BEGIN
		INSERT INTO @tmpMatch
		SELECT
			p.serial,
			m.homeid,
			m.awayid,
			m.IsNeutral
		FROM @tmpResults AS p
			INNER JOIN @betParlayDetail AS b ON p.Serial = b.Serial
			INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
		WHERE p.statusid NOT IN (0, 1)
	END

	-- Calculate outstanding
	SELECT @Outstanding = MAX(Stake)
	FROM @tmpBettrans

	SELECT @Outstanding = @Outstanding - ISNULL(SUM(Stake), 0)
	FROM @tmpResults
	WHERE StatusId NOT IN (0, 1)

	DECLARE @Today SMALLDATETIME
	
	SELECT @Today = CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120)

	DECLARE @ExFromdate SMALLDATETIME
	DECLARE @ExTodate SMALLDATETIME 

	SELECT @ExFromdate = MIN(WinLostDate),
		@ExTodate = MAX(WinLostDate)
	FROM @tmpResults

	DECLARE @ExchangeRate TABLE (
		FirstExchangeDateByMonth	SMALLDATETIME,
		LastExchangeDateByMonth		SMALLDATETIME,
		Rate						FLOAT
	)

	-- Get exchange rate
	IF @BaseCurrency <> ''
	BEGIN
		INSERT INTO @ExchangeRate
		SELECT
			e.FromDate,
			e.ToDate,
			e.Rate
		FROM dbo.Lrf_f_GetExchangeRate(@ExFromDate, @ExToDate, @BaseCurrency, '') AS e
		WHERE e.ExchangeId = @Currency
			AND EXISTS (SELECT 1 FROM @tmpResults WHERE WinLostDate BETWEEN e.FromDate AND e.ToDate)

		SELECT @Outstanding = ISNULL(@Outstanding, 0) * e.Rate
		FROM dbo.Lrf_f_GetExchangeRate(@Today, @Today, @BaseCurrency, '') AS e
		WHERE e.ExchangeId = @Currency
	END
	ELSE
	BEGIN
		SELECT @Outstanding = ISNULL(@Outstanding, 0)
	END

	DECLARE @Actual_Stake	MONEY,
		@WinLost			MONEY,
		@Discount			MONEY

	SELECT
		@Actual_Stake = Actual_Stake,
		@WinLost = WinLost,
		@Discount = CASE
						WHEN ExtraInfo LIKE '%p1%' THEN
							ISNULL(CAST(('<xml>' + ExtraInfo + '</xml>') AS XML).value('data(/xml/p1/@d)[1]','MONEY'), 0)
						ELSE 0
					END
	FROM @tmpBettrans

	-- Return combo detail
	SELECT DISTINCT
		b.WinLostDate,
		b.Serial,
		b.StatusId,
		CASE b.StatusId
			WHEN 101 THEN 'REJECT'
			WHEN 102 THEN 'VOID'
			WHEN 103 THEN 'REFUND'
			WHEN 111 THEN 'DRAW'
			WHEN 112 THEN 'WON'
			WHEN 113 THEN 'LOSE'
			ELSE ''
		END AS Status,
		b.Modds,
		b.Stake * ISNULL(e.Rate, 1) AS Stake,
		CASE
			WHEN @Discount > 0 THEN @WinLost - @Actual_Stake
			ELSE b.WinLost - b.Stake
		END * ISNULL(e.Rate, 1) AS WinLost,
		b.Comm * ISNULL(e.Rate, 1) AS Comm,
		b.PlayerComm * ISNULL(e.Rate, 1) AS PlayerComm
	FROM @tmpResults AS b
		LEFT JOIN @ExchangeRate AS e ON b.WinLostDate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth
	WHERE b.StatusId NOT IN (0, 1)
	ORDER BY b.WinLostDate ASC

	SELECT DISTINCT * FROM @tmpMatch
END
GO
