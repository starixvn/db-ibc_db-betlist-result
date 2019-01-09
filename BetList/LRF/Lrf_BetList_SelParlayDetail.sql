/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_BetList_SelParlayDetail]
	@TransId	BIGINT,
	@CustId		INT
AS

/*
	Created: Henry@20101210
	Task : get parlay tickets
	DB: DBEXT.bodb02
	Original: [Age_BetList_SelParlayDetail]

	Revisions:
		- 20110930@Henry: Add column statusID
		- 20111229@Henry: change the way to get odds/oddstype/betteam to web dev
		- 20141106@Florent: fix show SS bettype, get betcheck
		- 20141212@Florent: fix when betcheck = '' will return NULL
		- 20150424@Jim: support Betradar (add column betcheck in result)
		- 20151203@Kos: Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]
		- 20160202@Kos: Support PH All In One 1.2 [#Redmine: 50897]
		- 20160414@Kos: Support Combo Parlay [#Redmine: 55282]
		- 20161007@Kos: Add product bet type range for sub tickets [Redmine: #65045]
		- 20170324@Kos: Hotfix - Mix Parlay duplciate ticket detail [Redmine: #73984]
		- 20170620@Kos: Support Betradar Virtual Sports [#Redmine: 77280]
		- 20180327@Kos: Increase TransDesc length to 1000 [#Redmine: 92433]
		- 20180514@Kos: Return ExchangeId instead of CurrencyCode [#Redmine: 94845]
		- 20181030@Kos: Hotfix - View parlay detail crossline [#Redmine: 103935]
					- Add new param @CustId, remove param @Langkey
		- 20190107@Kos: Support Parlay Changes [#Redmine: 107165]
*/

BEGIN
	SET NOCOUNT ON

	-- Get Sport Bettype Matrix
	DECLARE @SportBettype TABLE(ProductId TINYINT, Bettype SMALLINT, EventType TINYINT)

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype
	SELECT ProductID, BetType, EventType
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
	WHERE ProductID IN (1, 27)

	DECLARE @tmpParlay TABLE (
		TransId			BIGINT,
		BetId			TINYINT,
		BetCheck		VARCHAR(100),
		SportType		INT,
		LeagueId		INT,
		BetType			INT,
		Stake			MONEY,
		CurrencyId		INT,
		MatchId			INT,
		EventDate		DATETIME,
		ShowTime		NVARCHAR(50),
		HomeId			INT,
		AwayId			INT,
		Hdp1			SMALLMONEY,
		Hdp2			SMALLMONEY,
		Odds			MONEY,
		BetTeam			NVARCHAR(50),
		LiveHomeScore	SMALLINT,
		LiveAwayScore	SMALLINT,
		LiveIndicator	BIT,
		BetStatus		NVARCHAR(50),
		IsNeutral		BIT,
		Status			NVARCHAR(10),
		TransDesc		NVARCHAR(1000))

	DECLARE @RefNo		BIGINT,
		@CurrencyId		INT,
		@Status			NVARCHAR(10)

	SELECT
		@RefNo = b.refno,
		@CurrencyId = b.currency,
		@Status = b.status
	FROM dbo.bettrans AS b WITH (NOLOCK)
	WHERE b.transid = @TransId AND b.custid = @CustId

	IF @RefNo IS NULL
	BEGIN
		SELECT
			@RefNo = b.refno,
			@CurrencyId = b.currency,
			@Status = b.status
		FROM dbo.bettrans14 AS b WITH (NOLOCK)
		WHERE b.transid = @TransId AND b.custid = @CustId

		IF @RefNo IS NULL
		BEGIN
			SELECT
				@RefNo = b.refno,
				@CurrencyId = b.currency,
				@Status = b.status
			FROM DBARC.bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK)
			WHERE b.transid = @TransId AND b.custid = @CustId
		END
	END

	IF EXISTS (	SELECT 1
				FROM dbo.bettransm AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
				WHERE b.refno = @RefNo AND b.custid = @CustId )
	BEGIN
		INSERT INTO @tmpParlay
		SELECT
			b.transid,
			NULL,
			ISNULL(b.betcheck, '') AS BetCheck,
			m.sporttype,
			m.leagueid,
			b.bettype,
			b.stake,
			@CurrencyId,
			m.matchid,
			m.GlobalShowTime AS EventDate,
			CASE
				WHEN sbt.ProductID = 27 THEN CONVERT(NVARCHAR(50), m.kickofftime)
				ELSE m.showtime
			END AS ShowTime,
			m.homeid,
			m.awayid,
			b.hdp1,
			b.hdp2,
			b.odds,
			b.betteam,
			b.livehomescore,
			b.liveawayscore,
			b.liveindicator,
			m.betstatus,
			m.IsNeutral,
			CASE
				WHEN @Status IN ('Void', 'Reject') THEN ''
				WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
				WHEN b.status = 'WON' AND ISNULL(b.statuswinlost, 0) = 1 THEN 'Half Won'
				WHEN b.status = 'LOSE' AND ISNULL(b.statuswinlost, 0) = 3 THEN 'Half Lose'
				ELSE b.status
			END AS status,
			ISNULL(b.transdesc, '') AS transdesc
		FROM dbo.bettransm AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
			INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
		WHERE b.refno = @RefNo AND b.custid = @CustId
	END

	IF EXISTS (	SELECT 1
				FROM dbo.bettransm14 AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
				WHERE b.refno = @RefNo AND b.custid = @CustId )
	BEGIN
		INSERT INTO @tmpParlay
		SELECT
			b.transid,
			NULL,
			ISNULL(b.betcheck, '') AS BetCheck,
			m.sporttype,
			m.leagueid,
			b.bettype,
			b.stake,
			@CurrencyId,
			m.matchid,
			m.GlobalShowTime AS EventDate,
			CASE
				WHEN sbt.ProductID = 27 THEN CONVERT(NVARCHAR(50), m.kickofftime)
				ELSE m.showtime
			END AS ShowTime,
			m.homeid,
			m.awayid,
			b.hdp1,
			b.hdp2,
			b.odds,
			b.betteam,
			b.livehomescore,
			b.liveawayscore,
			b.liveindicator,
			m.betstatus,
			m.isNeutral,
			CASE
				WHEN @Status IN ('Void', 'Reject') THEN ''
				WHEN b.status = 'WON' AND ISNULL(b.statuswinlost, 0) = 1 THEN 'Half Won'
				WHEN b.status = 'LOSE' AND ISNULL(b.statuswinlost, 0) = 3 THEN 'Half Lose'
				ELSE b.status
			END AS status,
			ISNULL(b.transdesc, '') AS transdesc
		FROM dbo.bettransm14 AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
			INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
		WHERE b.refno = @RefNo AND b.custid = @CustId
	END

	IF EXISTS (	SELECT 1
				FROM DBARC.bodb_Archive.dbo.bettransm AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
				WHERE b.refno = @RefNo AND b.custid = @CustId )
	BEGIN
		INSERT INTO @tmpParlay
		SELECT
			b.transid,
			NULL,
			ISNULL(b.betcheck, '') AS BetCheck,
			m.sporttype,
			m.leagueid,
			b.bettype,
			b.stake,
			@CurrencyId,
			m.matchid,
			m.GlobalShowTime AS EventDate,
			CASE
				WHEN sbt.ProductID = 27 THEN CONVERT(NVARCHAR(50), m.kickofftime)
				ELSE m.showtime
			END AS ShowTime,
			m.homeid,
			m.awayid,
			b.hdp1,
			b.hdp2,
			b.odds,
			b.betteam,
			b.livehomescore,
			b.liveawayscore,
			b.liveindicator,
			m.betstatus,
			m.isNeutral,
			CASE
				WHEN @Status IN ('Void', 'Reject') THEN ''
				WHEN b.status = 'WON' AND ISNULL(b.statuswinlost, 0) = 1 THEN 'Half Won'
				WHEN b.status = 'LOSE' AND ISNULL(b.statuswinlost, 0) = 3 THEN 'Half Lose'
				ELSE b.status
			END AS status,
			ISNULL(b.transdesc, '') AS transdesc
		FROM DBARC.bodb_Archive.dbo.bettransm AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
			INNER JOIN DBARC.bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON b.matchid = m.matchid
		WHERE b.refno = @RefNo AND b.custid = @CustId
	END

	SELECT DISTINCT * FROM @tmpParlay
	ORDER BY TransId DESC
END




GO
GRANT EXECUTE ON [dbo].[Lrf_BetList_SelParlayDetail] TO [bodbLicenseeNet]
GO
GRANT EXECUTE ON [dbo].[Lrf_BetList_SelParlayDetail] TO [bodbAdminNet]
GO
