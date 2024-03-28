/*<info serverAlias="DBBOF-bodb02" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Monitor_Match3rdSel]
AS

/*
	Created: 20210908@Kos
	Task: Get list of running match3rd
	DB: DBBOF.bodb02

	Revision:
		- 20210908@Kos: Support Bitcoin [RedmineID: #160160]
*/

BEGIN
	SET NOCOUNT ON

	SELECT
		Match3rdId AS MatchId,
		League3rdId AS LeagueId,
		SportType,
		EndTime AS EventDate
	FROM dbo.match3rd WITH (NOLOCK)
	WHERE EventStatus <> 'completed'
END
GO
