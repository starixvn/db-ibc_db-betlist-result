/*<info serverAlias="DBBOF-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Age_CoreBetList_SelRunning]
	@CustId				INT
	, @RoleId			TINYINT
	, @MatchId			INT				= 0
	, @LiveIndicator	INT				= NULL
	, @BetTeam			NVARCHAR(20)	= ''
	, @BettypeMatrix	[dbo].[TVP_SportBettypeMatrix]	READONLY
AS

/*
	Created: Bobby
	Task: Aphla site - refactor betlist core 
	DB: DBBOF.bodb02

	Revisions:
		- 20150504@Bobby: Create new SP
		- 20150706@Bobby: Exclude Metric Gaming running ticket from bettrans table
		- 20150814@Bobby: #41600 - Update time range to datetime formation
		- 20150910@Bobby: Enhance performence for SP core. Apply TVP for input parameters
		- 20150925@Bobby: Add MO & CB ticket
		- 20151217@Kos: Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]
		- 20151217@Kos: Support Cockfighting (#Redmine: 48850)
		- 20171109@Kos: Return IsNeutral for neutral match [#Redmine: 86312]
		- 20171113@Kos: Wrong column name [#Redmine: 86508]
		- 20180328@Kos: Increase Transdesc length to 1000 [Redmine: #92841]
		- 20180617@Kos: Move SP from bodb_Age to bodb02 [#Redmine: 97037]
					- Don't support Metric Gaming and translog anymore
		- 20180621@Kos: Add index hint for Master and Agent level [#Redmine: 97249]
		- 20181002@Kos: Support 2 new status Result Pending and Under Settlement [#Redmine: 101949]
					- Remove param @Username, @Language, @Error, @ErrorMsg, @ColumnOutput
					- Don't support member level anymore
		- 20181218@Kos: Support E-Sports phase 2b [#Redmine: 106456]
		- 20190107@Kos: Support Parlay Changes [#Redmine: 105585]
		- 20190506@Kos: Show match KO time for single ticket [Redmine: #112092]
		- 20190722@Kos: Support new status Pending [#Redmine: 113142]
		- 20191028@Kos: Show Running status for Marked tickets [Redmine: #122391]
		- 20191127@Kos: Hotfix - Oddsspread data type [Redmine: #124483]
		- 20200922@Kos: Support Myanmar Odds [Redmine: #141825]
		- 20211004@Razor: Extend Data type of IP v6 [Redmine: #90903]
		- 20231004@Kos: Support Parlay Boost [Redmine: #194992]
		- 20231021@Kos: Hotfix - Not show odds for some tickets [Redmine: #195844]
		- 20231101@Razor: Return Device Type info [Redmine: #192667]

	Param's Explanation:
		- @BettypeMatrix	: Table TYPE variable

	Wrapped SP List:
		- Age_BetList_SelRunningByBettype_Ag
		- Age_BetList_SelRunningByBettype_MAg
		- Age_BetList_SelRunningByBettype_SAg
		- Age_BetList_SelRunningByBettypeMatch_Ag
		- Age_BetList_SelRunningByBettypeMatch_MAg
		- Age_BetList_SelRunningByBettypeMatch_SAg
*/

BEGIN
	SET NOCOUNT ON;

	DECLARE @Data TABLE (
		SportType			SMALLINT
		, CustId			INT
		, Username			NVARCHAR(50)
		, BetType			SMALLINT
		, LeagueId			INT
		, RefNo				BIGINT
		, TransId			BIGINT
		, BetId				BIGINT
		, MatchCode			NVARCHAR(50)
		, Race				NVARCHAR(20)
		, EventDate			DATETIME
		, MatchId			INT
		, HomeId			INT
		, AwayId			INT
		, BetStatus			NVARCHAR(50)
		, Hdp1				SMALLMONEY
		, Hdp2				SMALLMONEY
		, Odds				MONEY
		, MOdds				MONEY
		, Status			NVARCHAR(10)
		, SettlementStatus	TINYINT
		, Stake				MONEY
		, Actual_Stake		MONEY
		, TransDate			DATETIME
		, BetTeam			NVARCHAR(20)
		, APositionTaking	SMALLMONEY
		, MPositionTaking	SMALLMONEY
		, SPositionTaking	SMALLMONEY
		, TPositionTaking	SMALLMONEY
		, ADiscount			SMALLMONEY
		, MDiscount			SMALLMONEY
		, SDiscount			SMALLMONEY
		, LiveIndicator		BIT
		, LiveHomeScore		SMALLINT
		, LiveAwayScore		SMALLINT
		, Ip				VARCHAR(45)
		, IsNeutral			BIT
		, OddsType			TINYINT
		, ShowTime			NVARCHAR(50)
		, ComStatus			NVARCHAR(20)
		, BetCheck			NVARCHAR(50)
		, TransDesc			NVARCHAR(1000)
		, OddsSpread		MONEY
		, ExtraInfo			VARCHAR(1000)
		, ProductId			TINYINT
		, EventType			TINYINT
		, DeviceType		TINYINT
	)

	SELECT @CustId	= ISNULL(@CustId, 0)
		, @MatchId	= ISNULL(@MatchId, 0)
		, @BetTeam	= ISNULL(@BetTeam, '')

	IF @MatchId = 0
	BEGIN
		IF @RoleId = 2
		BEGIN
			INSERT INTO @Data
			SELECT
				0 Sporttype
				, b.custid
				, b.Username
				, b.bettype
				, 0 LeagueID
				, b.refno
				, b.transid
				, b.betid
				, '' MatchCode
				, '' Race
				, '' AS EventDate
				, b.matchid
				, 0 HomeID
				, 0 AwayID
				, '' AS BetStatus
				, b.hdp1
				, b.hdp2
				, b.odds
				, b.modds
				, CASE
					WHEN b.bettype NOT IN (9, 29) AND b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
					WHEN b.bettype IN (9, 29) AND b.status = 'running' THEN
						CASE
							WHEN EXISTS (SELECT 1 FROM dbo.bettransm AS bm WITH (NOLOCK)
										WHERE bm.custid = b.custid
											AND bm.refno = b.refno
											AND (bm.status = 'waiting'
												OR (bm.status = 'running' AND ISNULL(bm.SecAcceptFlag, 0) = 1 AND ISNULL(bm.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP)))
								THEN 'Waiting'
							ELSE b.status
						END
					ELSE b.status
				END AS Status
				, 0 AS SettlementStatus
				, b.stake
				, b.actual_stake
				, b.transdate
				, b.betteam
				, b.apositiontaking
				, b.mpositiontaking
				, b.spositiontaking
				, b.tpositiontaking
				, b.discount AS Adiscount --Agent
				, b.adiscount AS Mdiscount --Master
				, b.sdiscount AS Sdiscount --Super
				, b.liveindicator
				, b.livehomescore
				, b.liveawayscore
				, b.ip
				, CONVERT(BIT, 0) AS IsNeutral
				, b.oddstype
				, '' showtime
				, CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus
				, b.betcheck
				, '' AS TransDesc
				, b.OddsSpread
				, ISNULL(b.ExtraInfo, '') AS ExtraInfo
				, bt.ProductID
				, bt.EventType
				, b.DeviceType
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN @BettypeMatrix AS bt ON b.bettype = bt.bettype
			WHERE b.recommend = @CustId AND b.statusID IN (0, 1)
		END
	
		IF @RoleId = 3
		BEGIN
			INSERT INTO @Data
			SELECT 
				0 Sporttype
				, b.custid
				, b.Username
				, b.bettype
				, 0 LeagueID
				, b.refno
				, b.transid
				, b.betid
				, '' MatchCode
				, '' Race
				, '' AS EventDate
				, b.matchid
				, 0 HomeID
				, 0 AwayID
				, '' AS BetStatus
				, b.hdp1
				, b.hdp2
				, b.odds
				, b.modds
				, CASE
					WHEN b.bettype NOT IN (9, 29) AND b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
					WHEN b.bettype IN (9, 29) AND b.status = 'running' THEN
						CASE
							WHEN EXISTS (SELECT 1 FROM dbo.bettransm AS bm WITH (NOLOCK)
										WHERE bm.custid = b.custid
											AND bm.refno = b.refno
											AND (bm.status = 'waiting'
												OR (bm.status = 'running' AND ISNULL(bm.SecAcceptFlag, 0) = 1 AND ISNULL(bm.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP)))
								THEN 'Waiting'
							ELSE b.status
						END
					ELSE b.status
				END AS Status
				, 0 AS SettlementStatus
				, b.Stake
				, b.actual_stake
				, b.Transdate
				, b.Betteam
				, b.APositiontaking
				, b.MPositiontaking
				, b.SPositiontaking
				, b.tpositiontaking
				, b.discount AS Adiscount --Agent
				, b.adiscount AS Mdiscount --Master
				, b.sdiscount AS Sdiscount --Super
				, b.Liveindicator
				, b.Livehomescore
				, b.Liveawayscore
				, b.IP
				, CONVERT(BIT,0) IsNeutral
				, b.oddstype
				, '' showtime
				, CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus
				, b.betcheck
				, '' AS TransDesc
				, b.OddsSpread
				, ISNULL(b.ExtraInfo, '') AS ExtraInfo
				, bt.ProductID
				, bt.EventType
				, b.DeviceType
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN @BettypeMatrix AS bt ON b.bettype = bt.bettype
			WHERE b.mrecommend = @CustId AND b.statusID IN (0, 1)
		END
	
		IF @RoleId = 4
		BEGIN
			INSERT INTO @Data
			SELECT 
				0 Sporttype
				, b.custid
				, b.Username
				, b.bettype
				, 0 LeagueID
				, b.refno
				, b.transid
				, b.betid
				, '' MatchCode
				, '' Race
				, '' AS EventDate
				, b.matchid
				, 0 HomeID
				, 0 AwayID
				, '' AS BetStatus
				, b.hdp1
				, b.hdp2
				, b.odds
				, b.modds
				, CASE
					WHEN b.bettype NOT IN (9, 29) AND b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
					WHEN b.bettype IN (9, 29) AND b.status = 'running' THEN
						CASE
							WHEN EXISTS (SELECT 1 FROM dbo.bettransm AS bm WITH (NOLOCK)
										WHERE bm.custid = b.custid
											AND bm.refno = b.refno
											AND (bm.status = 'waiting'
												OR (bm.status = 'running' AND ISNULL(bm.SecAcceptFlag, 0) = 1 AND ISNULL(bm.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP)))
								THEN 'Waiting'
							ELSE b.status
						END
					ELSE b.status
				END AS Status
				, 0 AS SettlementStatus
				, b.stake
				, b.actual_stake
				, b.Transdate
				, b.Betteam
				, b.APositiontaking
				, b.MPositiontaking
				, b.SPositiontaking
				, b.tpositiontaking
				, b.discount AS Adiscount --Agent
				, b.adiscount AS Mdiscount --Master
				, b.sdiscount AS Sdiscount --Super
				, b.Liveindicator
				, b.Livehomescore
				, b.Liveawayscore
				, b.IP
				, CONVERT(BIT,0) IsNeutral
				, b.oddstype
				, '' showtime
				, CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus
				, b.BetCheck
				, '' AS TransDesc
				, b.OddsSpread
				, ISNULL(b.ExtraInfo, '') AS ExtraInfo
				, bt.ProductID
				, bt.EventType
				, b.DeviceType
			FROM dbo.bettrans b WITH (NOLOCK)
				INNER JOIN @BettypeMatrix bt ON b.bettype = bt.bettype
			WHERE b.srecommend = @CustId
				AND b.statusID IN (0, 1)
		END
	END
	ELSE
	BEGIN
		IF @RoleId = 2
		BEGIN
			INSERT INTO @Data
			SELECT
				0 Sporttype
				, b.custid
				, b.Username
				, b.bettype
				, 0 LeagueID
				, b.refno
				, b.transid
				, b.betid
				, '' MatchCode
				, '' Race
				, '' AS EventDate
				, b.matchid
				, 0 HomeID
				, 0 AwayID
				, '' AS BetStatus
				, b.hdp1
				, b.hdp2
				, b.Odds
				, b.Modds
				, CASE
					WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
					ELSE b.status
				END AS status
				, 0 AS SettlementStatus
				, b.Stake
				, b.actual_stake
				, b.transdate
				, b.betteam
				, b.APositiontaking
				, b.MPositiontaking
				, b.SPositiontaking
				, b.tpositiontaking
				, b.discount AS Adiscount --Agent
				, b.adiscount AS Mdiscount --Master
				, b.sdiscount AS Sdiscount --Super
				, b.Liveindicator
				, b.Livehomescore
				, b.Liveawayscore
				, b.IP
				, CONVERT(BIT,0) IsNeutral
				, b.oddstype
				, '' showtime
				, CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus
				, b.BetCheck
				, ''transdesc
				, b.OddsSpread
				, ISNULL(b.ExtraInfo, '') AS ExtraInfo
				, bt.productid
				, bt.eventtype
				, b.DeviceType
			FROM dbo.bettrans AS b WITH (NOLOCK, INDEX = IX_betrunning_recommend)
				INNER JOIN @BettypeMatrix AS bt ON b.bettype = bt.bettype
			WHERE b.recommend = @CustId
				AND b.statusID IN (0, 1)
				AND b.matchid = @MatchId
		END
	
		IF @RoleId = 3
		BEGIN
			INSERT INTO @Data
			SELECT 
				0 Sporttype
				, b.custid
				, b.Username
				, b.Bettype
				, 0 LeagueID
				, b.refno
				, b.transid
				, b.betid
				, '' MatchCode
				, '' Race
				, '' AS EventDate
				, b.matchid
				, 0 HomeID
				, 0 AwayID
				, '' AS BetStatus
				, b.hdp1
				, b.hdp2
				, b.Odds
				, b.Modds
				, CASE
					WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
					ELSE b.status
				END AS status
				, 0 AS SettlementStatus
				, b.Stake
				, b.actual_stake
				, b.transdate
				, b.betteam
				, b.APositiontaking
				, b.MPositiontaking
				, b.SPositiontaking
				, b.tpositiontaking
				, b.discount AS Adiscount --Agent
				, b.adiscount AS Mdiscount --Master
				, b.sdiscount AS Sdiscount --Super
				, b.Liveindicator
				, b.Livehomescore
				, b.Liveawayscore
				, b.IP
				, CONVERT(BIT,0) IsNeutral
				, b.oddstype
				, '' showtime
				, CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus
				, b.BetCheck
				, ''transdesc
				, b.OddsSpread
				, ISNULL(b.ExtraInfo, '') AS ExtraInfo
				, bt.productid
				, bt.eventtype
				, b.DeviceType
			FROM dbo.bettrans AS b WITH (NOLOCK, INDEX = IX_betrunning_mrecommend)
				INNER JOIN @BettypeMatrix AS bt ON b.bettype = bt.bettype
			WHERE b.mrecommend = @CustId
				AND b.statusID IN (0, 1)
				AND b.matchid = @MatchId
		END
	
		IF @RoleId = 4
		BEGIN
			INSERT INTO @Data
			SELECT 
				0 Sporttype
				, b.custid
				, b.Username
				, b.Bettype
				, 0 LeagueID
				, b.refno
				, b.transid
				, b.betid
				, '' MatchCode
				, '' Race
				, '' AS EventDate
				, b.matchid
				, 0 HomeID
				, 0 AwayID
				, '' AS BetStatus
				, b.hdp1
				, b.hdp2
				, b.Odds
				, b.Modds
				, CASE
					WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
					ELSE b.status
				END AS status
				, 0 AS SettlementStatus
				, b.Stake
				, b.actual_stake
				, b.transdate
				, b.betteam
				, b.APositiontaking
				, b.MPositiontaking
				, b.SPositiontaking
				, b.tpositiontaking
				, b.discount AS Adiscount --Agent
				, b.adiscount AS Mdiscount --Master
				, b.sdiscount AS Sdiscount --Super
				, b.Liveindicator
				, b.Livehomescore
				, b.Liveawayscore
				, b.IP
				, CONVERT(BIT,0) IsNeutral
				, b.oddstype
				, '' showtime
				, CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus
				, b.BetCheck
				, ''transdesc
				, b.OddsSpread
				, ISNULL(b.ExtraInfo, '') AS ExtraInfo
				, bt.productid
				, bt.eventtype
				, b.DeviceType
			FROM dbo.bettrans AS b WITH (NOLOCK, INDEX = IX_betrunning_srecommend)
				INNER JOIN @BettypeMatrix AS bt ON b.bettype = bt.bettype
			WHERE b.srecommend = @CustId
				AND b.statusID IN (0, 1)
				AND b.matchid = @MatchId
		END
	END

	IF @LiveIndicator IS NOT NULL OR @BetTeam <> ''
	BEGIN
		DELETE b
		FROM @Data AS b
			INNER JOIN @BettypeMatrix AS bt ON b.BetType = bt.Bettype
		WHERE ( @LiveIndicator IS NOT NULL
				AND bt.ProductID = 3
				AND b.Liveindicator <> @LiveIndicator)
			OR ( @BetTeam <> '' 
				AND bt.ProductID = 3
				AND b.betteam <> @BetTeam )
	END

	-- Get original odds for Mix Parlay
	IF EXISTS (SELECT 1 FROM @Data WHERE BetType = 29 AND BetTeam = '1')
	BEGIN
		DECLARE @TmpData TABLE (
			RefNo		BIGINT,
			Hdp2		SMALLMONEY,
			BoostRate	MONEY)

		INSERT INTO @TmpData
		SELECT
			b.RefNo,
			b.Hdp2,
			CASE
				WHEN b.bettype = 29 AND b.betteam = 1 AND b.oddsspread = 2 THEN
					ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p1/@bbp)[1]','MONEY'), 0)
				ELSE 0
			END AS BoostRate
		FROM @Data AS b
		WHERE b.BetType = 29 AND b.BetTeam = '1'

		DECLARE @TmpParlayData TABLE (
			RefNo	BIGINT,
			Odds	MONEY,
			MOdds	MONEY)

		-- Mix Parlay which having no settled sub ticket
		INSERT INTO @TmpParlayData
		SELECT
			b.RefNo,
			dbo.PRODUCT(bm.odds) AS Odds,
			dbo.PRODUCT(bm.odds) * (b.BoostRate + 1) - b.BoostRate AS MOdds
		FROM @TmpData AS b
			INNER JOIN dbo.bettransm AS bm WITH (NOLOCK) ON bm.refno = b.RefNo
		GROUP BY
			b.RefNo,
			b.Hdp2,
			b.BoostRate
		HAVING COUNT(1) = b.Hdp2

		UPDATE b
		SET
			b.Odds = ISNULL(td.Odds, 0),
			b.MOdds = ISNULL(td.MOdds, 0)
		FROM @Data AS b
			LEFT JOIN @TmpParlayData AS td ON td.RefNo = b.RefNo
		WHERE b.BetType = 29 AND b.BetTeam = '1'
	END

	UPDATE b
	SET
		SportType	= m.sporttype,
		LeagueId	= m.leagueid,
		MatchCode	= m.matchcode,
		EventDate	= m.GlobalShowTime,
		HomeId		= m.homeid,
		AwayId		= m.awayid,
		BetStatus	= m.betstatus,
		SettlementStatus = ISNULL(m.SettlementStatus, 0),
		ShowTime	= m.showtime,
		IsNeutral	= m.IsNeutral
	FROM @Data AS b
		INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.MatchId = m.matchid
	WHERE b.EventType = 1

	UPDATE b
	SET
		SportType = l.sporttype,
		LeagueId = m.leagueid,
		MatchCode = m.matchcode,
		HomeId = m.teamid,
		AwayId = 0,
		ShowTime = ''
	FROM @Data AS b
		INNER JOIN dbo.outright AS m WITH (NOLOCK) ON b.MatchId = m.orid
		INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueid = l.leagueid
	WHERE b.EventType = 2

	SELECT * FROM @Data
	ORDER BY TransId DESC

	DECLARE @BettransDetail TABLE (
		RefNo				BIGINT
		, Odds				MONEY
		, Stake				MONEY
		, Status			NVARCHAR(10)
		, APositionTaking	SMALLMONEY
		, MPositionTaking	SMALLMONEY
		, SPositionTaking	SMALLMONEY
		, BetType			SMALLINT
		, BetTeam			NVARCHAR(10)
		, TransDesc			VARCHAR(300)
	)

	SELECT * FROM @BettransDetail
END
GO
