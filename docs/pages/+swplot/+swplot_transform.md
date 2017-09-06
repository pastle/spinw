---
{title: transform( ), keywords: sample, summary: transform objects on swplot figure,
  sidebar: sw_sidebar, permalink: +swplot_transform.html, folder: +swplot, mathjax: 'true'}

---
  transform objects on swplot figure
 
  SWPLOT.TRANSFORM(M, {hFigure})
 
  Transforms the objects on the active swplot figure using the
  transformation matrix M.
 
  Input:
 
  M         Transformation matrix with possible dimensions:
                4x4     This follows the Matlab standard for hgtransform.
                3x4     This is the SpinW format for space group 
                        transformations. 
                3x3     This defines the rotation matrix only.
            Setting M to 0 returns to the plot to the original orientation
            (equivalent to M=eye(4)).
  hFigure   Handle of the swplot figure window, optional.
 
 
  M = SWPLOT.TRANSFORM({hFigure})
 
  Returns the transformation matrix (4x4) of the active swplot figure.
 
  If the figure is created without the hgtransform object, the
  transformation matrix moves the camera.
 
  See also SWPLOT.FIGURE, HGTRANSFORM.
 