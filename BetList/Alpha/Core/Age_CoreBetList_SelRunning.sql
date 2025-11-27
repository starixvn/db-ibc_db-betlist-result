/*<info serverAlias="DBBOF-bodb02" executers="wsv_alp, wsv_alpv" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Age_CoreBetList_SelRunning]
	@CustId				INT
	, @RoleId			TINYINT
	, @MatchId			INT				= 0
	, @LiveIndicator	INT				= NULL
	, @BetTeam			NVARCHAR(20)	= ''
	, @BettypeMatrix	[dbo].[TVP_SportBettypeMatrix]	READONLY
AS

/*
	Created: Bobby
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
		- 20231129@Razor: Support Project 777 - return LeagueGroupId [Redmine: #194591]
		- 20241218@Razor: Support Direct Member [Redmine: #211969]
		- 20251103@Virgil: Support BetBuilder+ Hybrid Parlay [Redmine: #242378]

	Param's Explanation:
		- @BettypeMatrix	: Table TYPE variable

	Wrapped SP List:
		- Age_BetList_SelRunningByBettype_Ag
		- Age_BetList_SelRunningByBettype_MAg
		- Age_BetList_SelRunningByBettype_Sag
		- Age_BetList_SelRunningBybettypeMatch_Ag
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
		, LeagueGroupId		SMALLINT
	)

	SELECT @CustId	= ISNULL(@CustId, 0)
		, @MatchId	= ISNULL(@MatchId, 0)
		, @BetTeam	= ISNULL(@BetTeam, '')

	IF @MatchId = 0
	BEGIN
		IF @RoleId = 2
		BEGIN
			INSERT INTO @Data (
							SportType, CustId, Username, BetType, LeagueId, RefNo, TransId, BetId, MatchCode, Race, EventDate, MatchId, HomeId, AwayId, BetStatus, Hdp1,
							Hdp2, Odds, MOdds, Status, SettlementStatus, Stake, Actual_Stake, TransDate, BetTeam, APositionTaking, MPositionTaking, SPositionTaking, TPositionTaking,
							ADiscount, MDiscount, SDiscount, LiveIndicator, LiveHomeScore, LiveAwayScore, Ip, IsNeutral, OddsType, ShowTime, ComStatus, BetCheck, TransDesc, OddsSpread,
							ExtraInfo, ProductId, EventType, DeviceType, LeagueGroupId
			)
			SELECT
				0 Sporttype
				, b2.custid
				, b2.Username
				, b2.bettype
				, 0 LeagueID
				, b2.refno
				, b2.transid
				, b2.betid
				, '' MatchCode
				, '' Race
				, '' AS EventDate
				, b2.matchid
				, 0 HomeID
				, 0 AwayID
				, '' AS BetStatus
				, b2.hdp1
				, b2.hdp2
				, b2.odds
				, b2.modds
				, CASE
					WHEN b2.bettype NOT IN (9, 29) AND b2.status = 'running' AND ISNULL(b2.SecAcceptFlag, 0) = 1 AND ISNULL(b2.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
					WHEN b2.bettype IN (9, 29) AND b2.status = 'running' THEN
						CASE
							WHEN EXISTS (SELECT 1 FROM dbo.bettransm AS bm WITH (NOLOCK)
										WHERE bm.custid = b2.custid
											AND bm.refno = b2.refno
											AND (bm.status = 'waiting'
												OR (bm.status = 'running' AND ISNULL(bm.SecAcceptFlag, 0) = 1 AND ISNULL(bm.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP)))
								THEN 'Waiting'
							ELSE b2.status
						END
					ELSE b2.status
				END AS Status
				, 0 AS SettlementStatus
				, b2.stake
				, b2.actual_stake
				, b2.transdate
				, b2.betteam
				, b2.apositiontaking
				, b2.mpositiontaking
				, b2.spositiontaking
				, b2.tpositiontaking
				, CASE
					WHEN b2.recommend IN (-3, -4) THEN 0
					ELSE b2.discount
				END AS Adiscount --Agent
				, CASE
					WHEN b2.mrecommend = -4 THEN 0
					ELSE b2.adiscount
				END AS Mdiscount --Master
				, b2.sdiscount AS Sdiscount --Super
				, b2.liveindicator
				, b2.livehomescore
				, b2.liveawayscore
				, b2.ip
				, CONVERT(BIT, 0) AS IsNeutral
				, b2.oddstype
				, '' showtime
				, CASE WHEN b2.comstatus = '1' THEN '1' ELSE '0' END AS comstatus
				, b2.betcheck
				, IIF(b2.bettype = 29 AND b2.OddsSpread = 3, ISNULL(b2.transdesc, ''), '') AS TransDesc
				, b2.OddsSpread
				, ISNULL(b2.ExtraInfo, '') AS ExtraInfo
				, bt.ProductID
				, bt.EventType
				, b2.DeviceType
				, 0 AS LeagueGroupId
			FROM dbo.bettrans AS b2 WITH (NOLOCK)
				INNER JOIN @BettypeMatrix AS bt ON b2.bettype = bt.bettype
			WHERE b2.recommend = @CustId AND b2.statusID IN (0, 1)
		END
	
		IF @RoleId = 3
		BEGIN
			INSERT INTO @Data (
				SportType, CustId, Username, BetType, LeagueId, RefNo, TransId, BetId, MatchCode, Race, EventDate, MatchId, HomeId, AwayId, BetStatus, Hdp1,
				Hdp2, Odds, MOdds, Status, SettlementStatus, Stake, Actual_Stake, TransDate, BetTeam, APositionTaking, MPositionTaking, SPositionTaking, TPositionTaking,
				ADiscount, MDiscount, SDiscount, LiveIndicator, LiveHomeScore, LiveAwayScore, Ip, IsNeutral, OddsType, ShowTime, ComStatus, BetCheck, TransDesc, OddsSpread,
				ExtraInfo, ProductId, EventType, DeviceType, LeagueGroupId
			)
			SELECT 
				0 Sporttype
				, b3.custid
				, b3.Username
				, b3.bettype
				, 0 LeagueID
				, b3.refno
				, b3.transid
				, b3.betid
				, '' MatchCode
				, '' Race
				, '' AS EventDate
				, b3.matchid
				, 0 HomeID
				, 0 AwayID
				, '' AS BetStatus
				, b3.hdp1
				, b3.hdp2
				, b3.odds
				, b3.modds
				, CASE
					WHEN b3.bettype NOT IN (9, 29) AND b3.status = 'running' AND ISNULL(b3.SecAcceptFlag, 0) = 1 AND ISNULL(b3.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
					WHEN b3.bettype IN (9, 29) AND b3.status = 'running' THEN
						CASE
							WHEN EXISTS (SELECT 1 FROM dbo.bettransm AS bm WITH (NOLOCK)
										WHERE bm.custid = b3.custid
											AND bm.refno = b3.refno
											AND (bm.status = 'waiting'
												OR (bm.status = 'running' AND ISNULL(bm.SecAcceptFlag, 0) = 1 AND ISNULL(bm.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP)))
								THEN 'Waiting'
							ELSE b3.status
						END
					ELSE b3.status
				END AS Status
				, 0 AS SettlementStatus
				, b3.Stake
				, b3.actual_stake
				, b3.Transdate
				, b3.Betteam
				, b3.APositiontaking
				, b3.MPositiontaking
				, b3.SPositiontaking
				, b3.tpositiontaking
				, CASE
					WHEN b3.recommend IN (-3, -4) THEN 0
					ELSE b3.discount
				END AS Adiscount --Agent
				, CASE
					WHEN b3.mrecommend = -4 THEN 0
					ELSE b3.adiscount
				END AS Mdiscount --Master
				, b3.sdiscount AS Sdiscount --Super
				, b3.Liveindicator
				, b3.Livehomescore
				, b3.Liveawayscore
				, b3.IP
				, CONVERT(BIT,0) IsNeutral
				, b3.oddstype
				, '' showtime
				, CASE WHEN b3.comstatus = '1' THEN '1' ELSE '0' END AS comstatus
				, b3.betcheck
				, IIF(b3.bettype = 29 AND b3.OddsSpread = 3, ISNULL(b3.transdesc, ''), '') AS TransDesc
				, b3.OddsSpread
				, ISNULL(b3.ExtraInfo, '') AS ExtraInfo
				, bt.ProductID
				, bt.EventType
				, b3.DeviceType
				, 0 AS LeagueGroupId
			FROM dbo.bettrans AS b3 WITH (NOLOCK)
				INNER JOIN @BettypeMatrix AS bt ON b3.bettype = bt.bettype
			WHERE b3.mrecommend = @CustId AND b3.statusID IN (0, 1)
		END
	
		IF @RoleId = 4
		BEGIN
			INSERT INTO @Data (
				SportType, CustId, Username, BetType, LeagueId, RefNo, TransId, BetId, MatchCode, Race, EventDate, MatchId, HomeId, AwayId, BetStatus, Hdp1,
				Hdp2, Odds, MOdds, Status, SettlementStatus, Stake, Actual_Stake, TransDate, BetTeam, APositionTaking, MPositionTaking, SPositionTaking, TPositionTaking,
				ADiscount, MDiscount, SDiscount, LiveIndicator, LiveHomeScore, LiveAwayScore, Ip, IsNeutral, OddsType, ShowTime, ComStatus, BetCheck, TransDesc, OddsSpread,
				ExtraInfo, ProductId, EventType, DeviceType, LeagueGroupId
			)
			SELECT 
				0 Sporttype
				, b4.custid
				, b4.Username
				, b4.bettype
				, 0 LeagueID
				, b4.refno
				, b4.transid
				, b4.betid
				, '' MatchCode
				, '' Race
				, '' AS EventDate
				, b4.matchid
				, 0 HomeID
				, 0 AwayID
				, '' AS BetStatus
				, b4.hdp1
				, b4.hdp2
				, b4.odds
				, b4.modds
				, CASE
					WHEN b4.bettype NOT IN (9, 29) AND b4.status = 'running' AND ISNULL(b4.SecAcceptFlag, 0) = 1 AND ISNULL(b4.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
					WHEN b4.bettype IN (9, 29) AND b4.status = 'running' THEN
						CASE
							WHEN EXISTS (SELECT 1 FROM dbo.bettransm AS bm WITH (NOLOCK)
										WHERE bm.custid = b4.custid
											AND bm.refno = b4.refno
											AND (bm.status = 'waiting'
												OR (bm.status = 'running' AND ISNULL(bm.SecAcceptFlag, 0) = 1 AND ISNULL(bm.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP)))
								THEN 'Waiting'
							ELSE b4.status
						END
					ELSE b4.status
				END AS Status
				, 0 AS SettlementStatus
				, b4.stake
				, b4.actual_stake
				, b4.Transdate
				, b4.Betteam
				, b4.APositiontaking
				, b4.MPositiontaking
				, b4.SPositiontaking
				, b4.tpositiontaking
				, CASE
					WHEN b4.recommend IN (-3, -4) THEN 0
					ELSE b4.discount
				END AS Adiscount --Agent
				, CASE
					WHEN b4.mrecommend = -4 THEN 0
					ELSE b4.adiscount
				END AS Mdiscount --Master
				, b4.sdiscount AS Sdiscount --Super
				, b4.Liveindicator
				, b4.Livehomescore
				, b4.Liveawayscore
				, b4.IP
				, CONVERT(BIT,0) IsNeutral
				, b4.oddstype
				, '' showtime
				, CASE WHEN b4.comstatus = '1' THEN '1' ELSE '0' END AS comstatus
				, b4.BetCheck
				, IIF(b4.bettype = 29 AND b4.OddsSpread = 3, ISNULL(b4.transdesc, ''), '') AS TransDesc
				, b4.OddsSpread
				, ISNULL(b4.ExtraInfo, '') AS ExtraInfo
				, bt.ProductID
				, bt.EventType
				, b4.DeviceType
				, 0 AS LeagueGroupId
			FROM dbo.bettrans AS b4 WITH (NOLOCK)
				INNER JOIN @BettypeMatrix bt ON b4.bettype = bt.bettype
			WHERE b4.srecommend = @CustId
				AND b4.statusID IN (0, 1)
		END
	END
	ELSE
	BEGIN
		IF @RoleId = 2
		BEGIN
			INSERT INTO @Data (
				SportType, CustId, Username, BetType, LeagueId, RefNo, TransId, BetId, MatchCode, Race, EventDate, MatchId, HomeId, AwayId, BetStatus, Hdp1,
				Hdp2, Odds, MOdds, Status, SettlementStatus, Stake, Actual_Stake, TransDate, BetTeam, APositionTaking, MPositionTaking, SPositionTaking, TPositionTaking,
				ADiscount, MDiscount, SDiscount, LiveIndicator, LiveHomeScore, LiveAwayScore, Ip, IsNeutral, OddsType, ShowTime, ComStatus, BetCheck, TransDesc, OddsSpread,
				ExtraInfo, ProductId, EventType, DeviceType, LeagueGroupId
			)
			SELECT
				0 Sporttype
				, bm2.custid
				, bm2.Username
				, bm2.bettype
				, 0 LeagueID
				, bm2.refno
				, bm2.transid
				, bm2.betid
				, '' MatchCode
				, '' Race
				, '' AS EventDate
				, bm2.matchid
				, 0 HomeID
				, 0 AwayID
				, '' AS BetStatus
				, bm2.hdp1
				, bm2.hdp2
				, bm2.Odds
				, bm2.Modds
				, CASE
					WHEN bm2.status = 'running' AND ISNULL(bm2.SecAcceptFlag, 0) = 1 AND ISNULL(bm2.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
					ELSE bm2.status
				END AS status
				, 0 AS SettlementStatus
				, bm2.Stake
				, bm2.actual_stake
				, bm2.transdate
				, bm2.betteam
				, bm2.APositiontaking
				, bm2.MPositiontaking
				, bm2.SPositiontaking
				, bm2.tpositiontaking
				, CASE
					WHEN bm2.recommend IN (-3, -4) THEN 0
					ELSE bm2.discount
				END AS Adiscount --Agent
				, CASE
					WHEN bm2.mrecommend = -4 THEN 0
					ELSE bm2.adiscount
				END AS Mdiscount --Master
				, bm2.sdiscount AS Sdiscount --Super
				, bm2.Liveindicator
				, bm2.Livehomescore
				, bm2.Liveawayscore
				, bm2.IP
				, CONVERT(BIT,0) IsNeutral
				, bm2.oddstype
				, '' showtime
				, CASE WHEN bm2.comstatus = '1' THEN '1' ELSE '0' END AS comstatus
				, bm2.BetCheck
				, IIF(bm2.bettype = 29 AND bm2.OddsSpread = 3, ISNULL(bm2.transdesc, ''), '') AS transdesc
				, bm2.OddsSpread
				, ISNULL(bm2.ExtraInfo, '') AS ExtraInfo
				, bt.productid
				, bt.eventtype
				, bm2.DeviceType
				, 0 AS LeagueGroupId
			FROM dbo.bettrans AS bm2 WITH (NOLOCK, INDEX = IX_betrunning_recommend)
				INNER JOIN @BettypeMatrix AS bt ON bm2.bettype = bt.bettype
			WHERE bm2.recommend = @CustId
				AND bm2.statusID IN (0, 1)
				AND bm2.matchid = @MatchId
		END
	
		IF @RoleId = 3
		BEGIN
			INSERT INTO @Data (
				SportType, CustId, Username, BetType, LeagueId, RefNo, TransId, BetId, MatchCode, Race, EventDate, MatchId, HomeId, AwayId, BetStatus, Hdp1,
				Hdp2, Odds, MOdds, Status, SettlementStatus, Stake, Actual_Stake, TransDate, BetTeam, APositionTaking, MPositionTaking, SPositionTaking, TPositionTaking,
				ADiscount, MDiscount, SDiscount, LiveIndicator, LiveHomeScore, LiveAwayScore, Ip, IsNeutral, OddsType, ShowTime, ComStatus, BetCheck, TransDesc, OddsSpread,
				ExtraInfo, ProductId, EventType, DeviceType, LeagueGroupId
			)
			SELECT 
				0 Sporttype
				, bm3.custid
				, bm3.Username
				, bm3.Bettype
				, 0 LeagueID
				, bm3.refno
				, bm3.transid
				, bm3.betid
				, '' MatchCode
				, '' Race
				, '' AS EventDate
				, bm3.matchid
				, 0 HomeID
				, 0 AwayID
				, '' AS BetStatus
				, bm3.hdp1
				, bm3.hdp2
				, bm3.Odds
				, bm3.Modds
				, CASE
					WHEN bm3.status = 'running' AND ISNULL(bm3.SecAcceptFlag, 0) = 1 AND ISNULL(bm3.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
					ELSE bm3.status
				END AS status
				, 0 AS SettlementStatus
				, bm3.Stake
				, bm3.actual_stake
				, bm3.transdate
				, bm3.betteam
				, bm3.APositiontaking
				, bm3.MPositiontaking
				, bm3.SPositiontaking
				, bm3.tpositiontaking
				, CASE
					WHEN bm3.recommend IN (-3, -4) THEN 0
					ELSE bm3.discount
				END AS Adiscount --Agent
				, CASE
					WHEN bm3.mrecommend = -4 THEN 0
					ELSE bm3.adiscount
				END AS Mdiscount --Master
				, bm3.sdiscount AS Sdiscount --Super
				, bm3.Liveindicator
				, bm3.Livehomescore
				, bm3.Liveawayscore
				, bm3.IP
				, CONVERT(BIT,0) IsNeutral
				, bm3.oddstype
				, '' showtime
				, CASE WHEN bm3.comstatus = '1' THEN '1' ELSE '0' END AS comstatus
				, bm3.BetCheck
				, IIF(bm3.bettype = 29 AND bm3.OddsSpread = 3, ISNULL(bm3.transdesc, ''), '') AS transdesc
				, bm3.OddsSpread
				, ISNULL(bm3.ExtraInfo, '') AS ExtraInfo
				, bt.productid
				, bt.eventtype
				, bm3.DeviceType
				, 0 AS LeagueGroupId
			FROM dbo.bettrans AS bm3 WITH (NOLOCK, INDEX = IX_betrunning_mrecommend)
				INNER JOIN @BettypeMatrix AS bt ON bm3.bettype = bt.bettype
			WHERE bm3.mrecommend = @CustId
				AND bm3.statusID IN (0, 1)
				AND bm3.matchid = @MatchId
		END
	
		IF @RoleId = 4
		BEGIN
			INSERT INTO @Data (
				SportType, CustId, Username, BetType, LeagueId, RefNo, TransId, BetId, MatchCode, Race, EventDate, MatchId, HomeId, AwayId, BetStatus, Hdp1,
				Hdp2, Odds, MOdds, Status, SettlementStatus, Stake, Actual_Stake, TransDate, BetTeam, APositionTaking, MPositionTaking, SPositionTaking, TPositionTaking,
				ADiscount, MDiscount, SDiscount, LiveIndicator, LiveHomeScore, LiveAwayScore, Ip, IsNeutral, OddsType, ShowTime, ComStatus, BetCheck, TransDesc, OddsSpread,
				ExtraInfo, ProductId, EventType, DeviceType, LeagueGroupId
			)
			SELECT 
				0 Sporttype
				, bm4.custid
				, bm4.Username
				, bm4.Bettype
				, 0 LeagueID
				, bm4.refno
				, bm4.transid
				, bm4.betid
				, '' MatchCode
				, '' Race
				, '' AS EventDate
				, bm4.matchid
				, 0 HomeID
				, 0 AwayID
				, '' AS BetStatus
				, bm4.hdp1
				, bm4.hdp2
				, bm4.Odds
				, bm4.Modds
				, CASE
					WHEN bm4.status = 'running' AND ISNULL(bm4.SecAcceptFlag, 0) = 1 AND ISNULL(bm4.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
					ELSE bm4.status
				END AS status
				, 0 AS SettlementStatus
				, bm4.Stake
				, bm4.actual_stake
				, bm4.transdate
				, bm4.betteam
				, bm4.APositiontaking
				, bm4.MPositiontaking
				, bm4.SPositiontaking
				, bm4.tpositiontaking
				, CASE
					WHEN bm4.recommend IN (-3, -4) THEN 0
					ELSE bm4.discount
				END AS Adiscount --Agent
				, CASE
					WHEN bm4.mrecommend = -4 THEN 0
					ELSE bm4.adiscount
				END AS Mdiscount --Master
				, bm4.sdiscount AS Sdiscount --Super
				, bm4.Liveindicator
				, bm4.Livehomescore
				, bm4.Liveawayscore
				, bm4.IP
				, CONVERT(BIT,0) IsNeutral
				, bm4.oddstype
				, '' showtime
				, CASE WHEN bm4.comstatus = '1' THEN '1' ELSE '0' END AS comstatus
				, bm4.BetCheck
				, IIF(bm4.bettype = 29 AND bm4.OddsSpread = 3, ISNULL(bm4.transdesc, ''), '') AS transdesc
				, bm4.OddsSpread
				, ISNULL(bm4.ExtraInfo, '') AS ExtraInfo
				, bt.productid
				, bt.eventtype
				, bm4.DeviceType
				, 0 AS LeagueGroupId
			FROM dbo.bettrans AS bm4 WITH (NOLOCK, INDEX = IX_betrunning_srecommend)
				INNER JOIN @BettypeMatrix AS bt ON bm4.bettype = bt.bettype
			WHERE bm4.srecommend = @CustId
				AND bm4.statusID IN (0, 1)
				AND bm4.matchid = @MatchId
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

		INSERT INTO @TmpData (RefNo, Hdp2, BoostRate)
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
		INSERT INTO @TmpParlayData (RefNo, Odds, MOdds)
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
		IsNeutral	= m.IsNeutral,
		LeagueGroupId = l.LeagueGroupId
	FROM @Data AS b
		INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.MatchId = m.matchid
		INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueid = l.leagueid
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

	SELECT
		d.SportType,
		d.CustId,
		d.Username,
		d.BetType,
		d.LeagueId,
		d.RefNo,
		d.TransId,
		d.BetId,
		d.MatchCode,
		d.Race,
		d.EventDate,
		d.MatchId,
		d.HomeId,
		d.AwayId,
		d.BetStatus,
		d.Hdp1,
		d.Hdp2,
		d.Odds,
		d.MOdds,
		d.Status,
		d.SettlementStatus,
		d.Stake,
		d.Actual_Stake,
		d.TransDate,
		d.BetTeam,
		d.APositionTaking,
		d.MPositionTaking,
		d.SPositionTaking,
		d.TPositionTaking,
		d.ADiscount,
		d.MDiscount,
		d.SDiscount,
		d.LiveIndicator,
		d.LiveHomeScore,
		d.LiveAwayScore,
		d.Ip,
		d.IsNeutral,
		d.OddsType,
		d.ShowTime,
		d.ComStatus,
		d.BetCheck,
		d.TransDesc,
		d.OddsSpread,
		d.ExtraInfo,
		d.ProductId,
		d.EventType,
		d.DeviceType,
		d.LeagueGroupId,
		ex.currency
	FROM @Data AS d
		LEFT JOIN dbo.Customer AS c WITH (NOLOCK) ON c.CustId = d.CustId
		LEFT JOIN dbo.Exchange AS ex WITH (NOLOCK) ON c.currency = ex.exchangeid
	ORDER BY d.TransId DESC

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

	SELECT RefNo,
		Odds,
		Stake,
		Status,
		APositionTaking,
		MPositionTaking,
		SPositionTaking,
		BetType,
		BetTeam,
		TransDesc 
	FROM @BettransDetail
END
GO
