/*<info serverAlias="DBBOF-bodb02" executers="wsv_alp, wsv_alpv" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Age_BetList_LastBets_LeagueSel]
	@IsShowAll	BIT	= 0
AS

/*
	Created: Kos@20230704
	Task: Last Bets - Get league list
	DB: DBAGE.bodb02
	Revision:
		- 20230704@Kos: Last Bets [Redmine: #186142]
		- 20231129@Razor: Support Project 777 - return LeagueGroupId [Redmine: #194591]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	SELECT DISTINCT
		l.leagueid,
		l.leaguename,
		l.sporttype,
		l.leaguegroupId
	FROM (
			SELECT DISTINCT m.leagueid
			FROM dbo.match AS m WITH (NOLOCK)
				INNER JOIN dbo.SportBettypeMatrix AS sbt WITH (NOLOCK) ON sbt.SportType = m.sporttype
			WHERE sbt.ProductID = 1
				AND sbt.IsTest IN (0, @IsTest)
				AND m.eventstatus <> 'completed'

			UNION ALL

			SELECT DISTINCT l.leagueid
			FROM dbo.outright AS o WITH (NOLOCK)
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON l.leagueid = o.leagueid
				INNER JOIN dbo.SportBettypeMatrix AS sbt WITH (NOLOCK) ON sbt.SportType = l.sporttype
			WHERE sbt.ProductID = 1
				AND sbt.IsTest IN (0, @IsTest)
				AND o.oddsstatus <> 'completed'
		) AS t
		INNER JOIN dbo.League AS l WITH (NOLOCK) ON l.leagueid = t.leagueid
	WHERE l.isTest = CASE WHEN @IsShowAll = 1 THEN l.isTest ELSE @IsShowAll END
END
GO
