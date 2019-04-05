/*<info serverAlias="DB042-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[CS_Monitor_BetTypeSel]
AS

/*
	Created: Kos@20190405
	Task: CN88 Wager Monitoring - Get bettype
	DB: DB042.bodb02

	Revisions:
		- 20190409@Kos: Create new [Redmine: 111245]
*/

BEGIN
	SET NOCOUNT ON;

	DECLARE @IsTest BIT

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	SELECT DISTINCT
		s.SportTypeGroup,
		s.BetTypeGroup AS DisplayBetTypeGroup,
		CONVERT(VARCHAR(5), s.BetTypeGroup) AS BetTypeGroup,
		0 AS IsMainMarket
	FROM dbo.CS_SportBettypeMatrix AS s WITH (NOLOCK)
		INNER JOIN dbo.bettype AS b WITH (NOLOCK) ON s.BetTypeGroup = b.typeid
	WHERE IsTest <= 1 AND ProductID = 1

	UNION ALL

	SELECT DISTINCT
		0,
		s.BetTypeGroup AS DisplayBetTypeGroup,
		CASE
			WHEN s.BetTypeGroup = 1 THEN '1,7'
			WHEN s.BetTypeGroup = 2 THEN '2,12'
			WHEN s.BetTypeGroup = 3 THEN '3,8'
			WHEN s.BetTypeGroup = 4 THEN '4,30'
			WHEN s.BetTypeGroup = 5 THEN '5,15,20,21'
			ELSE CONVERT(VARCHAR(5), s.BetTypeGroup)
		END AS BetTypeGroup,
		CASE
			WHEN s.BetTypeGroup IN (1, 2, 3, 4, 5) THEN 1
			ELSE 0
		END AS IsMainMarket
	FROM dbo.CS_SportBettypeMatrix AS s WITH (NOLOCK)
		INNER JOIN dbo.bettype AS b WITH (NOLOCK) ON s.BetTypeGroup = b.typeid
	WHERE IsTest <= 1 AND ProductID = 1
		AND BetTypeGroup NOT IN (7, 12, 8, 30, 15, 20, 21)
	ORDER BY SportTypeGroup,DisplayBetTypeGroup
END
GO




GRANT EXECUTE ON [dbo].[CS_Monitor_BetTypeSel] TO [bodbDownlineNet] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[CS_Monitor_BetTypeSel] TO [bodbDownlineNetView] AS [dbo]
GO
