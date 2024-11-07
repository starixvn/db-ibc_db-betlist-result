/*<info serverAlias="DBBOF-bodb02" executers="wsv_alp,wsv_alpv" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Age_BetList_LastBets_SAg_BetCount]
	@CustId			INT,
	@TransId		BIGINT			= 0	OUTPUT,
	@MemberList		VARCHAR(MAX)	= '0',
	@BetTypeList	VARCHAR(MAX)	= '0',
	@SportTypeList	VARCHAR(MAX)	= '0',
	@LeagueList		VARCHAR(MAX)	= '0',
	@LiveIndicator	TINYINT			= 3,
	@MinStake		MONEY			= 0,
	@BetCount		INT				= 0	OUTPUT
AS

/*
	Created: 20241107@Razor
	Task: Alpha - Last Bets - Get number of tickets
	DB: DBBOF.bodb02

	Revision:
		- 20241107@Razor: Support Telegram notification [Redmine: #213315]

	Parameter's Explanation:
		- @CustId: Super CustId
		- @TransId: latest transid
		- @MemberList: list of member
			+ '0' : All members
		- @BetTypeList: list of bettype
			+ '0': All bettypes
		- @SportTypeList: list of sport type
			+ '0': All sport types
		- @LeagueList: list of league
			+ '0': All leagues
		- @LiveIndicator: ticket live status (0 : non-live, 1 : live , 2 : mix non live & live, 3: All)
		- @MinStake: min stake
		- @BetCount: number of tickets
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @MainBetTypeList VARCHAR(MAX) = '1,2,3,5,6,7,8,12,15,20,21,22,126,153,154,155,156,219,405,413,414,416,501,609,610,611,612,701,704,705,707,708,709,3918,9001,9002,9003,9008,9058,9059,9404,9405'

	-- Get child bet types
	SELECT @MainBetTypeList = @MainBetTypeList + ',' + CONVERT(VARCHAR(6), bettype)
	FROM dbo.f_GroupBettype()
	WHERE ',' + @MainBetTypeList + ',' LIKE '%,' + CONVERT(VARCHAR(6), GroupTypeId) + ',%'

	IF @BetTypeList <> '0'
	BEGIN
		SELECT @BetTypeList = @BetTypeList + ',' + CONVERT(VARCHAR(6), bettype)
		FROM dbo.f_GroupBettype()
		WHERE ',' + @BetTypeList + ',' LIKE '%,' + CONVERT(VARCHAR(6), GroupTypeId) + ',%'
	END

	DECLARE @IsTest BIT

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	; WITH __bettypeList AS (
		SELECT BetType, EventType
		FROM dbo.SportBettypeMatrix WITH (NOLOCK)
		WHERE ProductID = 1
			AND IsTest IN (0, @IsTest)
			AND 1 = CASE
						WHEN @BetTypeList = '0' THEN 1
						WHEN ',' + @BetTypeList + ',' LIKE '%,' + CONVERT(VARCHAR(6), BetType) + ',%' THEN 1
						WHEN ',' + @BetTypeList + ',' LIKE '%,-1,%'
							AND ',' + @MainBetTypeList + ',' NOT LIKE '%,' + CONVERT(VARCHAR(6), BetType) + ',%' THEN 1
						ELSE 0
					END
			AND (@SportTypeList = '0' OR EventType <> 0)
		GROUP BY BetType, EventType
	)
	SELECT
		@TransId = ISNULL(MAX(b.transid), @TransId),
		@BetCount = COUNT(1)
	FROM dbo.bettrans AS b WITH (NOLOCK)
		INNER JOIN __bettypeList AS sbm ON sbm.BetType = b.bettype
		LEFT JOIN dbo.match AS m WITH (NOLOCK) ON m.matchid = b.matchid AND sbm.EventType = 1
		LEFT JOIN dbo.outright AS o WITH (NOLOCK) ON o.orid = b.matchid AND sbm.EventType = 2
		LEFT JOIN dbo.League AS l WITH (NOLOCK) ON l.leagueid = o.leagueid AND sbm.EventType = 2
	WHERE b.srecommend = @CustId
		AND b.statusID IN (0, 1)
		AND b.transid > @TransId
		AND b.bettype NOT BETWEEN 801 AND 806
		AND 1 = CASE
					WHEN @LiveIndicator = 3 THEN 1
					WHEN b.bettype IN (9, 29) AND b.livehomescore = @LiveIndicator THEN 1
					WHEN b.bettype NOT IN (9, 29) AND b.liveindicator = @LiveIndicator THEN 1
					ELSE 0
				END
		ANd b.stake >= @MinStake
		AND 1 = CASE
					WHEN @MemberList = '0' THEN 1
					WHEN ',' + @MemberList + ',' LIKE '%,' + CONVERT(VARCHAR(11), b.custid) + ',%' THEN 1
					ELSE 0
				END
		AND 1 = CASE
					WHEN @SportTypeList = '0' THEN 1
					WHEN sbm.EventType = 1 AND ',' + @SportTypeList + ',' LIKE '%,' + CONVERT(VARCHAR(6), m.sporttype) + ',%' THEN 1
					WHEN sbm.EventType = 2 AND ',' + @SportTypeList + ',' LIKE '%,' + CONVERT(VARCHAR(6), l.sporttype) + ',%' THEN 1
					WHEN sbm.EventType = 1 AND ',' + @LeagueList + ',' LIKE '%,' + CONVERT(VARCHAR(11), m.leagueid) + ',%' THEN 1
					WHEN sbm.EventType = 2 AND ',' + @LeagueList + ',' LIKE '%,' + CONVERT(VARCHAR(11), l.leagueid) + ',%' THEN 1
					ELSE 0
				END
END
GO
