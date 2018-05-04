/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="vnteam" isFunction="0" isNested="0"></info>*/
USE bodb02
GO

ALTER PROCEDURE [dbo].[Age_BetList_TotalBets_BF_Ag]
	@CustId		INT,	-- Agent CustId
	@MatchId	INT
AS

/*
	Created: Kos@20171108
	Task: Bet list of Total Bets of Bullfighting
	DB: DBAGE.bodb02
	Revisions:
		- 20171108@Kos: Create new [#Redmine: 84961]
		- 20180117@Kos: Add Match No for Bullfighting [#Redmine: 84961]
*/

BEGIN
	SET NOCOUNT ON

	-- Get SportBetTypeMatrix
	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	DECLARE @SportBetType TABLE (ProductId TINYINT, BetType SMALLINT, EventType TINYINT)

	INSERT INTO @SportBetType
	SELECT ProductID, BetType, EventType
	FROM dbo.f_SportBettypeMatrixByProduct_Sel(30, @IsTest)

	-- Temp table
	DECLARE @Data TABLE (
		TransId			BIGINT,
		RefNo			BIGINT,
		BetId			BIGINT,
		CustId			INT,
		Username		NVARCHAR(50),
		TransDate		DATETIME,
		WinLostDate		DATETIME,
		SportType		SMALLINT,
		BetType			SMALLINT,
		BetTeam			NVARCHAR(10),
		Hdp1			SMALLMONEY,
		Odds			MONEY,
		OddsType		TINYINT,
		Status			NVARCHAR(10),
		LiveIndicator	BIT,
		LeagueId		INT,
		MatchId			INT,
		MatchCode		NVARCHAR(50),
		HomeId			INT,
		AwayId			INT,
		Stake			MONEY,
		Actual_Stake	MONEY,
		APositionTaking	SMALLMONEY,
		MPositionTaking	SMALLMONEY,
		SPositionTaking	SMALLMONEY,
		ADiscount		SMALLMONEY,
		MDiscount		SMALLMONEY,
		SDiscount		SMALLMONEY,
		Ip				NVARCHAR(15),
		BetCheck		NVARCHAR(50),
		TransDesc		NVARCHAR(1000)
	)

	-- Get data
	INSERT INTO @Data
	SELECT
		b.translogid AS TransId,
		b.translogid AS RefNo,
		0 AS BetId,
		@CustId AS CustId,
		b.Username AS Username,
		b.transdate,
		b.winlostdate,
		m.SportType,
		b.gameID AS BetType,
		b.custom3 AS BetTeam,
		CONVERT(SMALLMONEY, ISNULL(b.custom2, 0)) AS Hdp1,
		b.odds,
		CONVERT(TINYINT, ISNULL(b.custom1, 0)) AS OddsType,
		b.status,
		b.liveindicator,
		m.League3rdId AS LeagueId,
		m.Match3rdId AS MatchId,
		m.MatchNo AS MatchCode,
		m.HomeId,
		m.AwayId,
		b.stake,
		b.actual_stake,
		b.apositiontaking,
		b.mpositiontaking,
		b.spositiontaking,
		b.discount AS ADiscount,
		b.adiscount AS MDiscount,
		b.sdiscount AS SDiscount,
		b.ip,
		ISNULL(b.Tranid3rd, '') AS BetCheck,
		ISNULL(b.transdesc, '') AS TransDesc
	FROM
		dbo.translog AS b WITH (NOLOCK)
		INNER JOIN dbo.Match3rd AS m WITH (NOLOCK) ON b.eventID = m.Match3rdId
		INNER JOIN @SportBetType AS s ON s.BetType = b.gameID
	WHERE b.recommend = @CustId
		AND b.statusID IN (0, 1)
		AND b.eventID = @MatchId

	SELECT * FROM @Data
	ORDER BY TransId DESC
END


GO
GRANT EXECUTE ON [dbo].[Age_BetList_TotalBets_BF_Ag] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_BetList_TotalBets_BF_Ag] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_BetList_TotalBets_BF_Ag] TO [vnteam]
GO
