/*<info serverAlias="DBAGE-bodb02" executers="bodbAdminNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Acc_BetsSelBetCheckM_All]
	@TransId	BIGINT,
	@RefNo		BIGINT,
	@CustId		INT,
	@IsCN88		BIT = 0
AS

/*
	Created by: Henry
	Date: 2009-12-05
	Task: Get info of Mix Parlay Bets
	DB: DBAGE.bodb02
	Original: Acc_BetsSelBetCheckM

	Revisions:
		- 20101007@Henry: Change column transid from INT to BIGINT
		- 20110513@Lukas: Re-arrange bettype
		- 20110928@Johnson: Get column statusid to mark void sub-ticket
		- 20120629@Sophia: Remove function f_GetOddsByBettype, f_ShowOddsByBettype,f_GetChoice for odds, Oddstype, betteam
		- 20130121@Dan: Change linked server DB06 to DBARC
		- 20141006@Sophia: Get Betcheck
		- 20151210@Kos: Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]
		- 20160119@Kos: Return transdesc to support PH All In One 1.2 [#Redmine: 50897]
		- 20160407@Kos: Add TransId param, support Combo Parlay [#Redmine: 55282]
		- 20161010@Kos: Add product bet type range for sub tickets [Redmine: #65045]
		- 20170207@Kos: Add DISTINCT to prevent duplicate ticket detail [Redmine: #71007]
		- 20170616@Kos: Support Betradar Virtual Sports [#Redmine: 77280]
		- 20180328@Kos: Increase Transdesc length to 1000 [Redmine: #92841]
		- 20181022@Kos: Hotfix - View Parlay crossline [Redmine: #103171]
					- Add new param @CustId, remove param @Language
		- 20190107@Kos: Support Parlay Changes [#Redmine: 105585]
		- 20190426@Kos: Show Reject status on Parlay sub ticket [Redmine: #112286]
		- 20190521@Kos: Support CN88 [Redmine: #112225]
					- Add new param @IsCN88 BIT
		- 20200422@Kos: Support status Delay Payout [Redmine: #132629]
		- 20201028@Kos: Return transdate [Redmine: #144388]
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

	DECLARE @BetListMP TABLE (
		TransId				BIGINT,
		BetType				INT,
		Stake				MONEY,
		Currency			NVARCHAR(50),
		HomeId				INT,
		AwayId				INT,
		Hdp1				SMALLMONEY,
		Hdp2				SMALLMONEY,
		Odds				MONEY,
		BetTeam				NVARCHAR(10),
		Status				NVARCHAR(10),
		SettlementStatus	TINYINT,
		TransDate			DATETIME,
		LiveHomeScore		SMALLINT,
		LiveAwayScore		SMALLINT,
		LiveIndicator		BIT,
		LeagueId			INT,
		SportType			SMALLINT,
		IsNeutral			BIT,
		MatchId				INT,
		MatchCode			NVARCHAR(50),
		EventDate			DATETIME,
		ShowTime			NVARCHAR(50),
		BetCheck			NVARCHAR(50),
		TransDesc			NVARCHAR(1000)
	)

	-- Get currency name
	DECLARE @CurrencyName	NVARCHAR(50),
		@Status				NVARCHAR(10)

	SELECT
		@CurrencyName = ex.currency,
		@Status = b.status
	FROM dbo.bettrans AS b WITH (NOLOCK)
		INNER JOIN dbo.Exchange AS ex WITH (NOLOCK) ON b.currency = ex.exchangeid
	WHERE b.transid = @TransId AND b.custid = @CustId

	IF @CurrencyName IS NULL
	BEGIN
		SELECT
			@CurrencyName = ex.currency,
			@Status = b.status
		FROM dbo.bettrans14 AS b WITH (NOLOCK)
			INNER JOIN dbo.Exchange AS ex WITH (NOLOCK) ON b.currency = ex.exchangeid
		WHERE b.transid = @TransId AND b.custid = @CustId

		IF @CurrencyName IS NULL
		BEGIN
			SELECT
				@CurrencyName = ex.currency,
				@Status = b.status
			FROM DBARC.bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK)
				INNER JOIN dbo.Exchange AS ex WITH (NOLOCK) ON b.currency = ex.exchangeid
			WHERE b.transid = @TransId AND b.custid = @CustId
		END
	END

	-- Get parlay selection detail
	IF EXISTS(	SELECT 1
				FROM dbo.bettransm AS bm WITH (NOLOCK)
					INNER JOIN @SportBettype AS sbt ON bm.bettype = sbt.Bettype
				WHERE bm.refno = @RefNo AND bm.custid = @CustId)
	BEGIN
		INSERT INTO @BetListMP
		SELECT
			b.transid,
			b.bettype,
			b.stake,
			@CurrencyName AS Currency,
			m.homeid,
			m.awayid,
			b.hdp1,
			b.hdp2,
			b.odds,
			b.betteam,
			CASE
				WHEN @Status = 'Void' THEN ''
				WHEN @Status = 'Reject' AND b.status <> 'Reject' THEN ''
				WHEN @IsCN88 = 1 AND @Status = 'Reject' AND b.status = 'Reject' THEN ''
				WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
				WHEN b.status = 'WON' AND ISNULL(b.statuswinlost, 0) = 1 THEN 'Half Won'
				WHEN b.status = 'LOSE' AND ISNULL(b.statuswinlost, 0) = 3 THEN 'Half Lose'
				ELSE b.status
			END AS status,
			ISNULL(m.SettlementStatus, 0) AS SettlementStatus,
			b.transdate,
			b.livehomescore,
			b.liveawayscore,
			b.liveindicator,
			m.leagueid,
			m.sporttype,
			m.IsNeutral,
			m.matchid,
			m.matchcode,
			m.GlobalShowTime AS EventDate,
			CASE
				WHEN sbt.ProductID = 27 THEN CONVERT(NVARCHAR(50), m.kickofftime)
				ELSE m.showtime
			END AS ShowTime,
			b.betcheck,
			b.transdesc
		FROM dbo.bettransm AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
			INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
		WHERE b.refno = @RefNo AND b.custid = @CustId
	END

	IF EXISTS(	SELECT 1
				FROM dbo.bettransm14 AS bm WITH (NOLOCK)
					INNER JOIN @SportBettype AS sbt ON bm.bettype = sbt.Bettype
				WHERE bm.refno = @RefNo AND bm.custid = @CustId)
	BEGIN
		INSERT INTO @BetListMP
		SELECT
			b.transid,
			b.bettype,
			b.stake,
			@CurrencyName AS Currency,
			m.homeid,
			m.awayid,
			b.hdp1,
			b.hdp2,
			b.odds,
			b.betteam,
			CASE
				WHEN @Status = 'Void' THEN ''
				WHEN @Status = 'Reject' AND b.status <> 'Reject' THEN ''
				WHEN @IsCN88 = 1 AND @Status = 'Reject' AND b.status = 'Reject' THEN ''
				WHEN b.status = 'WON' AND ISNULL(b.statuswinlost, 0) = 1 THEN 'Half Won'
				WHEN b.status = 'LOSE' AND ISNULL(b.statuswinlost, 0) = 3 THEN 'Half Lose'
				ELSE b.status
			END AS status,
			0 AS SettlementStatus,
			b.transdate,
			b.livehomescore,
			b.liveawayscore,
			b.liveindicator,
			m.leagueid,
			m.sporttype,
			m.IsNeutral,
			m.matchid,
			m.matchcode,
			m.GlobalShowTime AS EventDate,
			CASE
				WHEN sbt.ProductID = 27 THEN CONVERT(NVARCHAR(50), m.kickofftime)
				ELSE m.showtime
			END AS ShowTime,
			b.betcheck,
			b.transdesc
		FROM dbo.bettransm14 AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
			INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
		WHERE b.refno = @RefNo AND b.custid = @CustId
	END

	IF EXISTS(	SELECT 1
				FROM DBARC.bodb_Archive.dbo.bettransm AS bm WITH (NOLOCK)
					INNER JOIN @SportBettype AS sbt ON bm.bettype = sbt.Bettype
				WHERE bm.refno = @RefNo AND bm.custid = @CustId)
	BEGIN
		INSERT INTO @BetListMP
		SELECT
			b.transid,
			b.bettype,
			b.stake,
			@CurrencyName AS Currency,
			m.homeid,
			m.awayid,
			b.hdp1,
			b.hdp2,
			b.odds,
			b.betteam,
			CASE
				WHEN @Status = 'Void' THEN ''
				WHEN @Status = 'Reject' AND b.status <> 'Reject' THEN ''
				WHEN @IsCN88 = 1 AND @Status = 'Reject' AND b.status = 'Reject' THEN ''
				WHEN b.status = 'WON' AND ISNULL(b.statuswinlost, 0) = 1 THEN 'Half Won'
				WHEN b.status = 'LOSE' AND ISNULL(b.statuswinlost, 0) = 3 THEN 'Half Lose'
				ELSE b.status
			END AS status,
			0 AS SettlementStatus,
			b.transdate,
			b.livehomescore,
			b.liveawayscore,
			b.liveindicator,
			m.leagueid,
			m.sporttype,
			m.isNeutral,
			m.matchid,
			m.matchcode,
			m.GlobalShowTime AS EventDate,
			CASE
				WHEN sbt.ProductID = 27 THEN CONVERT(NVARCHAR(50), m.kickofftime)
				ELSE m.showtime
			END AS ShowTime,
			b.betcheck,
			b.transdesc
		FROM DBARC.bodb_Archive.dbo.bettransm AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
			INNER JOIN DBARC.bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON b.matchid = m.matchid
		WHERE b.refno = @RefNo AND b.custid = @CustId
	END

	SELECT DISTINCT * FROM @BetListMP
	ORDER BY TransId DESC
END
GO
