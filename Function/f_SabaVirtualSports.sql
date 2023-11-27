/*<info serverAlias="DBAGE-bodb02,DBEXT-bodb02" selecters="bodbDownlineNet,bodbDownlineNetView,bodbLicenseeNet" viewers="" isFunction="1" isNested="1"></info>*/

ALTER FUNCTION [dbo].[f_SabaVirtualSports] ()
RETURNS TABLE
RETURN

/*
	Created: 20231127@Kos
	Task: Get Saba Virtual Sports LeagueGroupID
	DB: DBAGE.bodb02, DBEXT.bodb02

	Revisions:
		- 20231127@Kos: Get Saba Virtual Sports LeagueGroupID [Redmine: #197440]
*/
	SELECT 42 AS LeagueGroupID
	UNION ALL	SELECT 74
	UNION ALL	SELECT 108
	UNION ALL	SELECT 113
	UNION ALL	SELECT 122
	UNION ALL	SELECT 151
GO

