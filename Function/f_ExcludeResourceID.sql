/*<info serverAlias="DBEXT-bodb02" selecters="wsv_lap" viewers="" isFunction="1" isNested="1"></info>*/

ALTER FUNCTION [dbo].[f_ExcludeResourceID]
(
)
RETURNS @ExcludeResourceID TABLE (SportType SMALLINT, ResourceID VARCHAR(20))
AS

/*
	Created: 20250905@Kelvin
	Task: Get list ResourceID exclude
	DB: DBEXT.bodb02

	Revisions:
		- 20250905@Kelvin: Basketball - Offer 32 new bettypes [Redmine: 235299]

	SELECT * FROM dbo.f_ExcludeResourceID()
*/

BEGIN

	INSERT INTO @ExcludeResourceID (SportType, ResourceID)
	SELECT 1 AS SportType, ResourceID
	FROM (VALUES
		('00'), ('01'), ('04'), ('05'), ('135'), ('168'), ('173'), ('174'), ('175'), ('176'), ('192'), ('193'),
		('206'), ('207'), ('208'), ('209'), ('210'), ('211'), ('212'), ('213'), ('214'), ('215'), ('376'), ('488'), ('489'), ('490'),
		('14F'), ('14L'), ('127F'), ('127L'),
		('160%'), ('164%'), ('169%'), ('180%'), ('216%'), ('217%'), ('221%'), ('222%'), ('223%'), ('224%'), ('225%'), ('226%'), ('227%'), ('228%'), ('229%'), ('486%'), ('487%')
		) AS v (ResourceID)

	UNION ALL

	SELECT 2 AS SportType, ResourceID
	FROM (VALUES
		('653%'), ('656%'), ('659%'), ('662%'), ('665%'), ('667%'), ('669%'), ('671%'), ('673%'), ('674%'), ('675%'), ('676%'), ('677%'), ('678%'), ('679%')
		, ('680%'), ('681%'), ('682%'), ('683%'), ('684%')
		) AS v (ResourceID)

	UNION ALL

	SELECT 50 AS SportType, ResourceID
	FROM (VALUES
		('00'), ('9442'), ('9443'),
		('9410%'), ('9411%'), ('9422%'), ('9423%'), ('9428%'), ('9429%'), ('9434%'), ('9435%'),
		('9454%'), ('9455%'), ('9460%'), ('9461%'), ('9484%'), ('9485%'), ('9490%'), ('9491%'),
		('9616%'), ('9617%'), ('9624%'), ('9625%'), ('9630%'), ('9631%'), ('9636%'), ('9637%'),
		('9650%'), ('9651%'), ('9656%'), ('9657%'), ('9662%'), ('9663%'), ('9668%'), ('9671%'),
		('9672%'), ('9675%'), ('9676%'), ('9680%'), ('9686%'), ('9690%'),
		('9708%'), ('9709%'), ('9730%'), ('9731%'), ('9736%'), ('9737%')
		) AS v (ResourceID)

	RETURN
END
