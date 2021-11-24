/*<info serverAlias="DBACC-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Age_BetList_SelParlayDetail]
	@TransId	BIGINT,
	@CustId		INT
AS

/*
	Created:
	Task: get parlay tickets
	DB: DBACC.bodb02
	Original: BetsSelMTeamList

	Revisions:
		- 20080104@Vinh: Change @refno to @transid
		- 20080106@Phuc: Add typenamee2,leaguename
		- 20080629@Viet: Remove Teamname, Leaguename, Sportname, TypeName
		- 20080505@Thien: Break DB06.bodb_archive into new SP
		- 20090406@HanhVu: Remove refno
		- 20090617@HiepVo: Fix the issue Mix Parlay Tennis - Cross Day - Move Bet problems: get more data in bettransm14 for Refno in Bettrans
		- 20091125@Henry: Select appropriate info to avoid redundant data
		- 20100427@Jamie: Order tickets by TransID
		- 20101007@Henry: Change column transid from INT to BIGINT
		- 20110928@Johnson: Get column statusid to mark void sub-tickets
		- 20111216@Sophia: Remove function f_GetOddsByBettype, f_GetChoice, f_ShowOddsByBettype
		- 20130121@Dan: Change linked server DB06 to DBARC
		- 20140925@Sophia: Get Betcheck
		- 20151203@Kos: Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]
		- 20160123@Kos: Return transdesc to support PH All In One 1.2 [Redmine: #50897]
		- 20160411@Kos: Support Combo Parlay [#Redmine: 55282]
		- 20161010@Kos: Add product bet type range for sub tables [Redmine: #65045]
		- 20170207@Kos: Add DISTINCT to prevent duplicate ticket detail [Redmine: #71007]
		- 20170620@Kos: Support Betradar Virtual Sports [#Redmine: 77280]
		- 20180328@Kos: Increase Transdesc length to 1000 [Redmine: #92841]
		- 20181022@Kos: Hotfix - View Parlay crossline [Redmine: #103171]
					- Add new param @CustId, remove param @Language
		- 20190107@Kos: Support Parlay Changes [#Redmine: 105585]
		- 20190311@Kos: Move to DB06 [#Redmine: 110058]
		- 20190426@Kos: Show Reject status on Parlay sub ticket [Redmine: #112286]
		- 20190926@Kos: Hotfix - duplicate data during Balance Up [Redmine: #120962]
		- 20200422@Kos: Support status Delay Payout [Redmine: #132629]
		- 20201028@Kos: Return transdate [Redmine: #144388]
		- 20210208@Kos: Support Cricket AIO [Redmine: 148963]
		- 20211123@Razor: Check Abnormal Parlay Ticket [Redmine: #163900]
*/

BEGIN
	SET NOCOUNT ON

	-- Get Sport Bettype Matrix (support Sportsbook, Betradar Virtual Sports only)
	DECLARE @SportBettype TABLE(ProductId TINYINT, Bettype SMALLINT, EventType TINYINT)

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype
	SELECT ProductID, BetType, EventType
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
	WHERE ProductID IN (1, 27)

	DECLARE @tmpParlay TABLE (
		TransId				BIGINT,
		SportType			INT,
		LeagueId			INT,
		BetType				INT,
		Stake				MONEY,
		Currency			NVARCHAR(50),
		MatchId				INT,
		EventDate			DATETIME,
		ShowTime			NVARCHAR(50),
		HomeId				INT,
		AwayId				INT,
		Hdp1				SMALLMONEY,
		Hdp2				SMALLMONEY,
		Odds				MONEY,
		BetTeam				NVARCHAR(50),
		Status				NVARCHAR(10),
		SettlementStatus	TINYINT,
		TransDate			DATETIME,
		LiveHomeScore		SMALLINT,
		LiveAwayScore		SMALLINT,
		LiveIndicator		BIT,
		BetStatus			NVARCHAR(50),
		IsNeutral			BIT,
		BetCheck			NVARCHAR(50),
		TransDesc			NVARCHAR(1000)
	)

	DECLARE @RefNo		BIGINT,
		@CurrencyName	NVARCHAR(50),
		@Status			NVARCHAR(10),
		@MainTicketIsMarked BIT

	SELECT @MainTicketIsMarked = COUNT(1)
	FROM dbo.MarkedTransaction WITH (NOLOCK)
	WHERE transid = @TransId 
		AND MatchId = 29

	SELECT
		@RefNo = b.refno,
		@CurrencyName = ex.currency,
		@Status = b.status
	FROM dbo.bettrans AS b WITH (NOLOCK)
		INNER JOIN dbo.Exchange AS ex WITH (NOLOCK) ON b.currency = ex.exchangeid
	WHERE b.transid = @TransId AND b.custid = @CustId

	IF @RefNo IS NULL
	BEGIN
		SELECT
			@RefNo = b.refno,
			@CurrencyName = ex.currency,
			@Status = b.status
		FROM dbo.bettrans14 AS b WITH (NOLOCK)
			INNER JOIN dbo.Exchange AS ex WITH (NOLOCK) ON b.currency = ex.exchangeid
		WHERE b.transid = @TransId AND b.custid = @CustId

		IF @RefNo IS NULL
		BEGIN
			SELECT
				@RefNo = b.refno,
				@CurrencyName = ex.currency,
				@Status = b.status
			FROM bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK)
				INNER JOIN dbo.Exchange AS ex WITH (NOLOCK) ON b.currency = ex.exchangeid
			WHERE b.transid = @TransId AND b.custid = @CustId
		END
	END

	IF EXISTS ( SELECT 1
				FROM dbo.bettransm AS bm WITH (NOLOCK)
					INNER JOIN @SportBettype AS sbt ON bm.bettype = sbt.Bettype
				WHERE bm.refno = @RefNo AND bm.custid = @CustId)
	BEGIN
		INSERT INTO @tmpParlay
		SELECT
			b.transid,
			m.sporttype,
			m.leagueid,
			b.bettype,
			b.stake,
			@CurrencyName AS Currency,
			CASE
				WHEN m.sporttype = 50 AND m.ChildMatchType = 200 THEN pm.matchid
				ELSE m.matchid
			END AS MatchId,
			CASE
				WHEN m.sporttype = 50 AND m.ChildMatchType = 200 THEN pm.GlobalShowTime
				ELSE m.GlobalShowTime
			END AS EventDate,
			CASE
				WHEN sbt.ProductID = 27 THEN CONVERT(NVARCHAR(50), m.kickofftime)
				WHEN m.sporttype = 50 AND m.ChildMatchType = 200 THEN pm.showtime
				ELSE m.showtime
			END AS ShowTime,
			m.homeid,
			m.awayid,
			b.hdp1,
			b.hdp2,
			b.odds,
			b.betteam,
			CASE
				WHEN @Status = 'Void' THEN ''
				WHEN @Status = 'Reject' AND b.status <> 'Reject' THEN ''
				WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
				WHEN b.status = 'WON' AND ISNULL(b.statuswinlost, 0) = 1 THEN 'Half Won'
				WHEN b.status = 'LOSE' AND ISNULL(b.statuswinlost, 0) = 3 THEN 'Half Lose'
				ELSE b.status
			END AS Status,
			CASE 
				WHEN b.status IN ('WON','LOSE','DRAW') AND @MainTicketIsMarked = 1 THEN 255
				ELSE ISNULL(m.SettlementStatus, 0)
			END AS SettlementStatus,
			b.transdate,
			b.livehomescore,
			b.liveawayscore,
			b.liveindicator,
			m.betstatus,
			m.IsNeutral,
			b.betcheck,
			ISNULL(b.transdesc, '') AS transdesc
		FROM dbo.bettransm AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
			INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
			LEFT JOIN dbo.match AS pm WITH (NOLOCK)
				ON pm.matchid = m.ParentID
				AND m.sporttype = 50
				AND m.ChildMatchType = 200
		WHERE b.refno = @RefNo AND b.custid = @CustId
	END

	IF EXISTS (	SELECT 1
				FROM dbo.bettransm14 AS bm WITH (NOLOCK)
					INNER JOIN @SportBettype AS sbt ON bm.bettype = sbt.Bettype
				WHERE bm.refno = @RefNo AND bm.custid = @CustId)
	BEGIN
		INSERT INTO @tmpParlay
		SELECT
			b.transid,
			m.sporttype,
			m.leagueid,
			b.bettype,
			b.stake,
			@CurrencyName AS Currency,
			CASE
				WHEN m.sporttype = 50 AND m.ChildMatchType = 200 THEN ISNULL(pm14.matchid, pm.matchid)
				ELSE m.matchid
			END AS MatchId,
			CASE
				WHEN m.sporttype = 50 AND m.ChildMatchType = 200 THEN ISNULL(pm14.GlobalShowTime, pm.GlobalShowTime)
				ELSE m.GlobalShowTime
			END AS EventDate,
			CASE
				WHEN sbt.ProductID = 27 THEN CONVERT(NVARCHAR(50), m.kickofftime)
				WHEN m.sporttype = 50 AND m.ChildMatchType = 200 THEN ISNULL(pm14.showtime, pm.showtime)
				ELSE m.showtime
			END AS ShowTime,
			m.homeid,
			m.awayid,
			b.hdp1,
			b.hdp2,
			b.odds,
			b.betteam,
			CASE
				WHEN @Status = 'Void' THEN ''
				WHEN @Status = 'Reject' AND b.status <> 'Reject' THEN ''
				WHEN b.status = 'WON' AND ISNULL(b.statuswinlost, 0) = 1 THEN 'Half Won'
				WHEN b.status = 'LOSE' AND ISNULL(b.statuswinlost, 0) = 3 THEN 'Half Lose'
				ELSE b.status
			END AS status,
			0 AS SettlementStatus,
			b.transdate,
			b.livehomescore,
			b.liveawayscore,
			b.liveindicator,
			m.betstatus,
			m.IsNeutral,
			b.betcheck,
			ISNULL(b.transdesc, '') AS transdesc
		FROM dbo.bettransm14 AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
			INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
			LEFT JOIN dbo.match14 AS pm14 WITH (NOLOCK)
				ON pm14.matchid = m.ParentID
				AND m.sporttype = 50
				AND m.ChildMatchType = 200
			LEFT JOIN dbo.match AS pm WITH (NOLOCK)
				ON pm.matchid = m.ParentID
				AND m.sporttype = 50
				AND m.ChildMatchType = 200
		WHERE b.refno = @RefNo AND b.custid = @CustId
	END

	IF EXISTS (	SELECT 1
				FROM bodb_Archive.dbo.bettransm AS bm WITH (NOLOCK)
					INNER JOIN @SportBettype AS sbt ON bm.bettype = sbt.Bettype
				WHERE bm.refno = @RefNo)
	BEGIN
		INSERT INTO @tmpParlay
		SELECT
			b.transid,
			m.sporttype,
			m.leagueid,
			b.bettype,
			b.stake,
			@CurrencyName AS Currency,
			CASE
				WHEN m.sporttype = 50 AND m.ChildMatchType = 200 THEN ISNULL(pmbk.matchid, ISNULL(pm14.matchid, pm.matchid))
				ELSE m.matchid
			END AS MatchId,
			CASE
				WHEN m.sporttype = 50 AND m.ChildMatchType = 200 THEN ISNULL(pmbk.GlobalShowTime, ISNULL(pm14.GlobalShowTime, pm.GlobalShowTime))
				ELSE m.GlobalShowTime
			END AS EventDate,
			CASE
				WHEN sbt.ProductID = 27 THEN CONVERT(NVARCHAR(50), m.kickofftime)
				WHEN m.sporttype = 50 AND m.ChildMatchType = 200 THEN ISNULL(pmbk.showtime, ISNULL(pm14.showtime, pm.showtime))
				ELSE m.showtime
			END AS ShowTime,
			m.homeid,
			m.awayid,
			b.hdp1,
			b.hdp2,
			b.odds,
			b.betteam,
			CASE
				WHEN @Status = 'Void' THEN ''
				WHEN @Status = 'Reject' AND b.status <> 'Reject' THEN ''
				WHEN b.status = 'WON' AND ISNULL(b.statuswinlost, 0) = 1 THEN 'Half Won'
				WHEN b.status = 'LOSE' AND ISNULL(b.statuswinlost, 0) = 3 THEN 'Half Lose'
				ELSE b.status
			END AS status,
			0 AS SettlementStatus,
			b.transdate,
			b.livehomescore,
			b.liveawayscore,
			b.liveindicator,
			m.betstatus,
			m.isNeutral,
			b.betcheck,
			ISNULL(b.transdesc, '') AS transdesc
		FROM bodb_Archive.dbo.bettransm AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
			INNER JOIN bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON b.matchid = m.matchid
			LEFT JOIN DBARC.bodb_Archive.dbo.match_bk AS pmbk WITH (NOLOCK)
				ON pmbk.matchid = m.ParentID
				AND m.sporttype = 50
				AND m.ChildMatchType = 200
			LEFT JOIN dbo.match14 AS pm14 WITH (NOLOCK)
				ON pm14.matchid = m.ParentID
				AND m.sporttype = 50
				AND m.ChildMatchType = 200
			LEFT JOIN dbo.match AS pm WITH (NOLOCK)
				ON pm.matchid = m.ParentID
				AND m.sporttype = 50
				AND m.ChildMatchType = 200
		WHERE b.refno = @RefNo AND b.custID = @CustId
	END

	SELECT DISTINCT * FROM @tmpParlay
	ORDER BY TransId DESC
END
GO
