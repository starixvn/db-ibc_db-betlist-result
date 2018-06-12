/*<info serverAlias="DBEXT-bodb02,DBACC-bodb02" selecters="bodbLicenseeNet" viewers="vnteam" isFunction="1" isNested="1"></info>*/
ALTER FUNCTION [dbo].[f_GetBetFromByPlatform] (@PlatformType TINYINT)
RETURNS @BetFrom TABLE (BetFrom NVARCHAR(1))
AS

 /*
	Created: Kos@20180712
	Task: Get bet from from platform
	DB: DBEXT.bodb02, DBACC.bodb02
	Param's Explanation:
		+ @PlatformType:
			- 0 - All: All
			- 1 - Asia: d (mobile), g (MG Download only)
			- 2 - China: a (dep-Singbet), z (dep2-SingBet)
			- 3 - Euro: e (Europe), u (dep-Euro), y (dep2-Euro)
			- 4 - WAP: m (dep-wap)
			- 5 - Smart Site: s (smartphone), l (dep-smart)
			- 6 - Tablet: r (dep2-tablet)
			- 7 - New Asia: x (dep2-Asia)

	Revisions:
		- 20180712@Kos: Created [#Redmine: 80941]
*/

BEGIN
	-- Asia
	IF @PlatformType IN (0, 1)
	BEGIN
		INSERT INTO @BetFrom
		SELECT 'd' UNION ALL
		SELECT 'g'
	END

	-- China
	IF @PlatformType IN (0, 2)
	BEGIN
		INSERT INTO @BetFrom
		SELECT 'a' UNION ALL
		SELECT 'z'
	END

	-- Euro
	IF @PlatformType IN (0, 3)
	BEGIN
		INSERT INTO @BetFrom
		SELECT 'e' UNION ALL
		SELECT 'u' UNION ALL
		SELECT 'y'
	END

	-- WAP
	IF @PlatformType IN (0, 4)
	BEGIN
		INSERT INTO @BetFrom
		SELECT 'm'
	END

	-- Smart Site
	IF @PlatformType IN (0, 5)
	BEGIN
		INSERT INTO @BetFrom
		SELECT 's' UNION ALL
		SELECT 'l'
	END

	-- Tablet
	IF @PlatformType IN (0, 6)
	BEGIN
		INSERT INTO @BetFrom
		SELECT 'r'
	END

	-- New Asia
	IF @PlatformType IN (0, 7)
	BEGIN
		INSERT INTO @BetFrom
		SELECT 'x'
	END

	RETURN
END



GO 
GRANT SELECT ON [dbo].[f_GetBetFromByPlatform] TO [bodbDownlineNetView]
GO 
GRANT SELECT ON [dbo].[f_GetBetFromByPlatform] TO [bodbDownlineNet]
GO
GRANT VIEW DEFINITION ON [dbo].[f_GetBetFromByPlatform] TO [vnteam]
GO
