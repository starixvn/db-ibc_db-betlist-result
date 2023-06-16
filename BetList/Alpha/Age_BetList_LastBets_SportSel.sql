/*<info serverAlias="DBBOF-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Age_BetList_LastBets_SportSel]
AS

/*
	Created: Kos@20230704
	Task: Last Bets - Get sport list
	DB: DBAGE.bodb02
	Revision:
		- 20230704@Kos: Last Bets [Redmine: #186142]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	SELECT DISTINCT
		s.SportType,
		s.SportName
	FROM dbo.Sports AS s WITH (NOLOCK)
		INNER JOIN dbo.SportBettypeMatrix AS sbt WITH (NOLOCK) ON sbt.SportType = s.SportType
	WHERE sbt.ProductID = 1
		AND sbt.IsTest IN (0, @IsTest)
		AND s.SportName NOT LIKE '%Upcoming%'
		AND s.SportType NOT IN (27, 154)
END
GO
