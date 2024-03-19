/*<info serverAlias="DBAGE-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_Result_GetSiteInfo_Mem]
	@CustId		INT			= 0,
	@Username	VARCHAR(30)	= ''
AS

/*
	Created: Kos@20170207
	Task: Get site info of a member
	DB: DBAGE.bodb02
	
	Revisions:
		20170207@Kos: Initialize SP
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @Site TABLE (
		SiteId		INT,
		SiteName	NVARCHAR(50)
	)

	IF @CustId = 0
	BEGIN
		SELECT @CustId = custid
		FROM dbo.Customer WITH (NOLOCK)
		WHERE username = @Username
	END

	INSERT INTO @Site
	SELECT s.siteid,
		s.site
	FROM dbo.Customer AS c WITH (NOLOCK)
		INNER JOIN dbo.Customer AS a WITH (NOLOCK) ON c.recommend = a.custid
		INNER JOIN dbo.Site AS s WITH (NOLOCK) ON a.site = s.site
	WHERE c.custid = @CustId

	SELECT * FROM @Site
END
GO