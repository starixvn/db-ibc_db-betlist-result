/*<info serverAlias="DBOST-bodb_ost" executers="wsv_alp, wsv_alpv" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Ost_BetList_TotalBet]
	@CustId			INT,
	@RoleId			TINYINT,
	@BetType		INT,
	@MatchId		INT				= 0,
	@LiveIndicator	BIT				= 0,
	@BetTeam		NVARCHAR(20)	= ''
AS

/*
	Created: 20191025@Kos
	Task: Bet List Total Bets for DBOST Testing
	DB: DBOST.bodb_ost
	Revisions:
		- 20191025@Kos: Created [Redmine: #114231]
		- 20211004@Razor: Extend Data type of IP v6 [Redmine: #90903]
*/

BEGIN
	SET NOCOUNT ON;

	DECLARE @SportBettype TABLE (ProductID TINYINT, Bettype SMALLINT, EventType TINYINT)

	-- Check SP Version
	DECLARE @IsTest BIT = 0

	SELECT @IsTest = bodb02.dbo.f_CheckSPVersion(@@PROCID)

	-- Gather BettypeMatrix
	INSERT INTO @SportBettype
	SELECT DISTINCT ProductID, BetType, EventType
	FROM bodb02.dbo.f_SportBettypeMatrix_Sel(0, 0, 0, 2, '', '', @IsTest)
	WHERE (@BetType = 6 	AND BetType IN (6, 159, 161, 162, 126, 179, 181, 182))
		OR (@BetType = 14 	AND BetType IN (14, 127))
		OR (@BetType = 2 	AND BetType IN (2, 157))
		OR (@BetType = 15 	AND BetType IN (15, 167))
		OR BetType = @BetType 

	DECLARE @Data TABLE (
		SportType			SMALLINT,
		CustId				INT,
		Username			NVARCHAR(50),
		BetType				SMALLINT,
		LeagueId			INT,
		RefNo				BIGINT,
		TransId				BIGINT,
		BetId				BIGINT,
		MatchCode			NVARCHAR(50),
		EventDate			DATETIME,
		MatchId				INT,
		HomeId				INT,
		AwayId				INT,
		BetStatus			NVARCHAR(50),
		Hdp1				SMALLMONEY,
		Hdp2				SMALLMONEY,
		Odds				MONEY,
		MOdds				MONEY,
		Status				NVARCHAR(10),
		SettlementStatus	TINYINT,
		Stake				MONEY,
		Actual_Stake		MONEY,
		TransDate			DATETIME,
		BetTeam				NVARCHAR(20),
		APositionTaking		SMALLMONEY,
		MPositionTaking		SMALLMONEY,
		SPositionTaking		SMALLMONEY,
		TPositionTaking		SMALLMONEY,
		ADiscount			SMALLMONEY,
		MDiscount			SMALLMONEY,
		SDiscount			SMALLMONEY,
		LiveIndicator		BIT,
		LiveHomeScore		SMALLINT,
		LiveAwayScore		SMALLINT,
		Ip					VARCHAR(45),
		IsNeutral			BIT,
		OddsType			TINYINT,
		ShowTime			NVARCHAR(50),
		ComStatus			NVARCHAR(20),
		BetCheck			NVARCHAR(50),
		ExtraInfo			VARCHAR(1000),
		ProductId			TINYINT,
		EventType			TINYINT
	)

	IF @RoleId = 2
	BEGIN
		INSERT INTO @Data (
			CustId,
			Username,
			BetType,
			RefNo,
			TransId,
			BetId,
			MatchId,
			Hdp1,
			Hdp2,
			Odds,
			MOdds,
			Status,
			Stake,
			Actual_Stake,
			TransDate,
			BetTeam,
			APositionTaking,
			MPositionTaking,
			SPositionTaking,
			TPositionTaking,
			ADiscount,
			MDiscount,
			SDiscount,
			LiveIndicator,
			LiveHomeScore,
			LiveAwayScore,
			Ip,
			OddsType,
			ComStatus,
			BetCheck,
			ExtraInfo,
			ProductId,
			EventType)
		SELECT
			b.custid,
			b.Username,
			b.bettype,
			b.refno,
			b.transid,
			b.betid,
			b.matchid,
			b.hdp1,
			b.hdp2,
			b.odds,
			b.modds,
			CASE
				WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
				ELSE b.status
			END AS status,
			b.stake,
			b.actual_stake,
			b.transdate,
			b.betteam,
			b.apositiontaking,
			b.mpositiontaking,
			b.spositiontaking,
			b.tpositiontaking,
			b.discount AS Adiscount,
			b.adiscount AS Mdiscount,
			b.sdiscount AS Sdiscount,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.ip,
			b.oddstype,
			CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus,
			b.betcheck,
			ISNULL(b.ExtraInfo, '') AS ExtraInfo,
			bt.productid,
			bt.eventtype
		FROM dbo.bettrans AS b WITH (NOLOCK, INDEX = IX_betrunning_recommend)
			INNER JOIN @SportBettype AS bt ON b.bettype = bt.bettype
		WHERE b.recommend = @CustId
			AND b.statusID IN (0, 1)
			AND b.matchid = @MatchId
	END
	
	IF @RoleId = 3
	BEGIN
		INSERT INTO @Data (
			CustId,
			Username,
			BetType,
			RefNo,
			TransId,
			BetId,
			MatchId,
			Hdp1,
			Hdp2,
			Odds,
			MOdds,
			Status,
			Stake,
			Actual_Stake,
			TransDate,
			BetTeam,
			APositionTaking,
			MPositionTaking,
			SPositionTaking,
			TPositionTaking,
			ADiscount,
			MDiscount,
			SDiscount,
			LiveIndicator,
			LiveHomeScore,
			LiveAwayScore,
			Ip,
			OddsType,
			ComStatus,
			BetCheck,
			ExtraInfo,
			ProductId,
			EventType)
		SELECT
			b.custid,
			b.Username,
			b.bettype,
			b.refno,
			b.transid,
			b.betid,
			b.matchid,
			b.hdp1,
			b.hdp2,
			b.odds,
			b.modds,
			CASE
				WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
				ELSE b.status
			END AS status,
			b.stake,
			b.actual_stake,
			b.transdate,
			b.betteam,
			b.apositiontaking,
			b.mpositiontaking,
			b.spositiontaking,
			b.tpositiontaking,
			b.discount AS Adiscount,
			b.adiscount AS Mdiscount,
			b.sdiscount AS Sdiscount,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.ip,
			b.oddstype,
			CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus,
			b.betcheck,
			ISNULL(b.ExtraInfo, '') AS ExtraInfo,
			bt.productid,
			bt.eventtype
		FROM dbo.bettrans AS b WITH (NOLOCK, INDEX = IX_betrunning_mrecommend)
			INNER JOIN @SportBettype AS bt ON b.bettype = bt.bettype
		WHERE b.mrecommend = @CustId
			AND b.statusID IN (0, 1)
			AND b.matchid = @MatchId
	END
	
	IF @RoleId = 4
	BEGIN
		INSERT INTO @Data (
			CustId,
			Username,
			BetType,
			RefNo,
			TransId,
			BetId,
			MatchId,
			Hdp1,
			Hdp2,
			Odds,
			MOdds,
			Status,
			Stake,
			Actual_Stake,
			TransDate,
			BetTeam,
			APositionTaking,
			MPositionTaking,
			SPositionTaking,
			TPositionTaking,
			ADiscount,
			MDiscount,
			SDiscount,
			LiveIndicator,
			LiveHomeScore,
			LiveAwayScore,
			Ip,
			OddsType,
			ComStatus,
			BetCheck,
			ExtraInfo,
			ProductId,
			EventType)
		SELECT
			b.custid,
			b.Username,
			b.bettype,
			b.refno,
			b.transid,
			b.betid,
			b.matchid,
			b.hdp1,
			b.hdp2,
			b.odds,
			b.modds,
			CASE
				WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
				ELSE b.status
			END AS status,
			b.stake,
			b.actual_stake,
			b.transdate,
			b.betteam,
			b.apositiontaking,
			b.mpositiontaking,
			b.spositiontaking,
			b.tpositiontaking,
			b.discount AS Adiscount,
			b.adiscount AS Mdiscount,
			b.sdiscount AS Sdiscount,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.ip,
			b.oddstype,
			CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS comstatus,
			b.betcheck,
			ISNULL(b.ExtraInfo, '') AS ExtraInfo,
			bt.productid,
			bt.eventtype
		FROM dbo.bettrans AS b WITH (NOLOCK, INDEX = IX_betrunning_srecommend)
			INNER JOIN @SportBettype AS bt ON b.bettype = bt.bettype
		WHERE b.srecommend = @CustId
			AND b.statusID IN (0, 1)
			AND b.matchid = @MatchId
	END

	IF @LiveIndicator IS NOT NULL OR @BetTeam <> ''
	BEGIN
		DELETE b
		FROM @Data AS b
			INNER JOIN @SportBettype AS bt ON b.BetType = bt.Bettype
		WHERE ( @LiveIndicator IS NOT NULL
				AND bt.ProductID = 3
				AND b.LiveIndicator <> @LiveIndicator)
			OR ( @BetTeam <> '' 
				AND bt.ProductID = 3
				AND b.BetTeam <> @BetTeam )
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
		INNER JOIN bodb02.dbo.match AS m WITH (NOLOCK) ON b.MatchId = m.matchid
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
		INNER JOIN bodb02.dbo.outright AS m WITH (NOLOCK) ON b.MatchId = m.orid
		INNER JOIN bodb02.dbo.League AS l WITH (NOLOCK) ON m.leagueid = l.leagueid
	WHERE b.EventType = 2

	SELECT * FROM @Data
	ORDER BY TransId DESC

	DECLARE @BettransDetail TABLE (
		RefNo			BIGINT,
		Odds			MONEY,
		Stake			MONEY,
		Status			NVARCHAR(10),
		APositionTaking	SMALLMONEY,
		MPositionTaking	SMALLMONEY,
		SPositionTaking	SMALLMONEY,
		BetType			SMALLINT,
		BetTeam			NVARCHAR(10),
		TransDesc		VARCHAR(300)
	)

	SELECT * FROM @BettransDetail
END
GO
