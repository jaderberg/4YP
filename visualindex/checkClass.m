function checkClass(obj,level)
% checkClass - checks a Java object or classname and displays its methods, enumerations & interfaces
%
% checkClass inspects the specified java object reference or class-name,
% and reports its superclass(es), and its new/modified methods, interfaces,
% enumerations, sub-classes and annotations.
%
% This utility complements the more detailed UIINSPECT utility (on the File Exchange)
% by being Command-Prompt based and also by highlighting the object
% components that were modified compared to its parent superclass.
%
% Syntax:
%    checkClass(javaObjectReference)
%    checkClass(javaClassName)
%    checkClass(...,level)  % default level=inf
%
% Examples:
%    checkClass(javax.swing.JButton)
%    checkClass('java.lang.String')
%    checkClass(com.mathworks.mde.desk.MLDesktop.getInstance)
%    jButton=javax.swing.JButton('Click me!');   jButton.checkClass;
%
% Bugs and suggestions:
%    Please send to Yair Altman (altmany at gmail dot com)
%
% See also:
%    methods, methodsview, uiinspect (on the File Exchange)
%
% Release history:
%    1.0  2009-04-13: initial version
%    1.1  2009-04-14: added classes, constructors, annotations
%    1.2  2010-01-31: displayed modified methods
%    1.3  2010-01-31: fixed displayed class names
%    1.4  2010-01-31: fixed duplicate interfaces list
%    1.5  2010-01-31: enabled classname input arg
%    1.6  2010-03-14: pretier display, hyperlinked classes, error checking
%    1.7  2010-03-15: displayed static field values; fixed minor bug; displayed missing/extra constructors
%    1.8  2010-05-07: linked to checkClass (not uiinspect); fixed some edge cases; displayed non-ML superclass; displayed class modifiers
%    1.9  2010-06-16: fixed problem when directly specifying requested superclass level
%    1.10 2011-01-02: fixed static fields value display; fixed minor bug with non-derived class
%    1.11 2011-01-02: enabled checking Matlab-wrapped (javahandle_withcallbacks) class handles
%    1.12 2011-01-31: displayed function return values & qualifiers; fixed dot-notation internal classes
%    1.13 2011-02-13: fixed edge cases of no methods and problematic classnames (e.g., '$proxy')
%    1.14 2011-03-17: added hyperlinks to user-generated subclasses (myclass$subclass)
%    1.15 2011-05-30: fixed display of array of string values

% License to use and modify this code is granted freely to all interested, as long as the original author is
% referenced and attributed as such. The original author maintains the right to be solely associated with this work.

% Programmed and Copyright by Yair M. Altman: altmany(at)gmail.com
% $Revision: 1.15 $  $Date: 2011/05/30 17:40:10 $

  try obj = java(obj);  catch, end  % handle Matlab-wrapped (javahandle_withcallbacks) class handles
  if isjava(obj)
      thisClass = obj.getClass;
  elseif ischar(obj)
      %disp 'Not a Java object';  return;
      try
          thisClass = loadClass(obj);
      catch
          try
              % One more attempt - maybe the last sub-segment is an internal class:
              obj = regexprep(obj,'\.([^.]+$)','\$$1');
              thisClass = loadClass(obj);
          catch
              thisClass = java.lang.String(obj);
          end
      end
  else
      disp 'Uncheckable object';
      return;
  end

  linkTarget = mfilename; %'uiinspect';
  if isempty(which('uiinspect'))
      warning('YMA:checkClass:noUIINSPECT','UIINSPECT utility was not found. Download from <a href="http://www.mathworks.com/matlabcentral/fileexchange/17935">here</a>');
      linkTarget = mfilename;
  end
  
  if nargin < 2
      level = Inf;
  elseif ischar(level)
      level = str2double(level);
  end          
  if numel(level)~=1 || ~isnumeric(level) || isnan(level)
      error('YMA:checkClass:badLevel','Level argument must be a number from 0-Inf');
  end      

  try
      thisClassName = char(thisClass.getName);
  catch
      try
          msgStr = ['Cannot process <' obj '> - possibly not a Java object or classname'];
      catch
          msgStr = 'Cannot process input object - possibly not a Java object or classname';
      end
      error('YMA:checkClass:badInput',msgStr);
  end
  modifiers = char(java.lang.reflect.Modifier.toString(thisClass.getModifiers));
  modifiers = strtrim(strrep(modifiers,'public',''));
  if isempty(modifiers),  modifiers = 'Class';  end
  disp ' ';
  disp([modifiers ' <a href="matlab:' linkTarget '(''' thisClassName ''')">' thisClassName ...
        '</a> (<a href="matlab:uiinspect(''' thisClassName ''')">uiinspect</a>)']);
  disp ' ';

  superclass = thisClass;
  superclassName = char(thisClass.getName);
  superclassFoundFlag = false;
  try
      while level>0 && (~superclassFoundFlag || nargin>1 || ~isempty(strfind(superclassName,'mathworks')))
          level = level - 1;
          superclass = superclass.getSuperclass;
          superclassName = char(superclass.getCanonicalName);
          disp(['Superclass: <a href="matlab:' linkTarget '(''' superclassName ''')">' superclassName '</a>']);
          superclassFoundFlag = true;
      end
  catch
      % Never mind - maybe no superclass...
  end
  if superclassFoundFlag,  disp ' ';  end

  % Display new/missing methods
  [objMethods,full] = getMethods(obj);
  supMethods = getMethods(superclassName);
  newMethods = diffValues('Methods',thisClassName,objMethods,superclassName,supMethods,1);
  %diffValues('Methods',thisClassName,obj.methods,superclassName,methods(superclassName),1);
  %diffValues2('Meths',thisClass,superclass,'getMethods');

  % Display modified methods, based on column 4 class
  if ~isempty(full)
      className = [thisClassName,'.'];
      thisClassMethodsIdx = strncmp(className,full(:,4),length(className));
      objMethods = regexprep(objMethods, ' [(].*','');
      modifiedMethods = setdiff(objMethods(thisClassMethodsIdx),newMethods);
      if ~isempty(modifiedMethods)
          str = 'defined by ';
          if superclassFoundFlag
              str = 'inherited & modified by ';
          end
          disp(['Methods ' str regexprep(thisClassName, '.*\.','') ':']);
          dispValues('',[],modifiedMethods)
          disp ' ';
      end
  end

  % Display new/missing interfaces
  %loopValues('Interfaces:',thisClass.getInterfaces);
  diffValues2('Interfaces',thisClass,superclass,'getInterfaces',0,obj);

  % Display possible enclosing method
  if ~isempty(thisClass.getEnclosingMethod)
      disp 'Enclosing method:'
      dispValues('',[],thisClass.getEnclosingMethod)
      disp ' ';
  end

  % Display new/missing constants, sub-classes, constructors etc.
  loopValues('Enum constants:',thisClass.getEnumConstants);
  diffValues2('Static fields',thisClass,superclass,'getFields',0,obj);
  diffValues2('Sub-classes',thisClass,superclass,'getClasses',0,obj);
  %diffValues2('Constructors',thisClass,superclass,'getConstructors',0,obj);
  diffValues2('Annotations',thisClass,superclass,'getAnnotations',0,obj);

function loadedClass = loadClass(className)
  try
      loadedClass = java.lang.Class.forName(className);
  catch
      classLoader = com.mathworks.jmi.ClassLoaderManager.getClassLoaderManager;
      loadedClass = classLoader.loadClass(className);
  end
end  % loadClass

function [objMethods,full] = getMethods(obj)
  objMethods = {};
  full = {};
  m = [];
  try
      [m,full] = methods(obj,'-full');
  catch
      % never mind - maybe no methods
  end
  %full2 = full(:,4:5)'; str = sprintf('%s%s\n',full2{:});
  for methodIdx = 1 : length(m)
      methodStr = [full{methodIdx,4},full{methodIdx,5}];
      if ~isempty(full{methodIdx,2}) && ~strcmp(full{methodIdx,2},'void')
          methodStr = [methodStr ' : ' full{methodIdx,2}];  %#ok grow
      end
      if ~isempty(full{methodIdx,1})
          methodStr = [methodStr ' (' full{methodIdx,1} ')'];  %#ok grow
      end
      objMethods{methodIdx,1} = regexprep(methodStr,'[^(]*\.','','once');  %#ok grow
  end
end  % getMethods

function cellStr = toChar(javaObjArray)
  if isempty(javaObjArray)
      cellStr = '';
  else
      cellStr = sort(cellfun(@(c)char(toString(c.getName)),javaObjArray.cell,'un',0));
  end
end  % toChar

function loopValues(title,javaObjArray)
  try
      data = toChar(javaObjArray);
  catch
      data = cellfun(@char,cell(javaObjArray),'un',0);
  end
  if ~isempty(data) && iscell(data)
      disp(title);
      for idx = 1 : length(data)
          disp(['     ' data{idx}]);
      end
      disp ' ';
  else
      %disp 'none';
  end 
end  % loopValues

function values = diffValues(title,thisClassName,thisValues,superClassName,superValues, flag, varargin)
  if isjava(thisValues),   thisValues  = toChar(thisValues);   end
  if isjava(superValues),  superValues = toChar(superValues);  end
  thisValuesSimple  = regexprep(thisValues, ' [(].*','');
  superValuesSimple = regexprep(superValues,' [(].*','');
  thisClassName2  = regexprep(thisClassName, '.*\.','');
  superClassName2 = regexprep(superClassName,'.*\.','');
  if nargin >= 6 && flag
      thisValues2  = regexprep(thisValuesSimple,  ['^' thisClassName2], superClassName2);  % =stripValue(thisValues, thisClassName2);
      superValues2 = regexprep(superValuesSimple, ['^' superClassName2], thisClassName2);  % =stripValue(superValues,superClassName2);
  else
      thisValues2  = thisValuesSimple;
      superValues2 = superValuesSimple;
  end
  [values,idx] = setdiff(superValuesSimple,thisValues2);
  if ~isempty(values)
      disp([title ' in ' superClassName2 ' missing in ' thisClassName2 ':'])
      dispValues(title, superClassName, superValues(idx), varargin{:})
      disp ' ';
  end
  [values,idx] = setdiff(thisValuesSimple,superValues2);
  if ~isempty(values)
      str = [title ' in ' thisClassName2];
      if ~isempty(superClassName2),  str = [str ' missing in ' superClassName2];  end
      disp([str ':'])
      dispValues(title, thisClassName, thisValues(idx), varargin{:})
      disp ' ';
  end
end  % diffValues

function dispValues(title,classname,values,obj)  %#ok used
  try
      try
          valuesStr = '';
          staticFlag = strcmpi(strtok(title),'static');
          maxFieldLen = max(cellfun(@length,values));
          for idx = 1 : length(values)
              try
                  if staticFlag
                      try
                          dataValue = eval([classname '.' values{idx}]);
                      catch
                          dataValue = eval(['obj.' values{idx}]);
                      end
                      if isa(dataValue,'java.lang.String')
                          dataValue = ['''' char(dataValue) ''''];
                      elseif isa(dataValue,'java.lang.String[]')
                          dataValue = cell(dataValue);
                          dataValue = sprintf('''%s'',', dataValue{:});
                          dataValue = ['{' dataValue(1:end-1) '}'];
                      end
                      padStr = repmat(' ',1,maxFieldLen-length(values{idx}));
                      try
                          valStr = num2str(dataValue);
                      catch
                          valStr = char(dataValue);
                      end
                      valuesStr = [valuesStr sprintf('   %s%s = %s\n',num2str(values{idx}),padStr,valStr)];  %#ok grow
                  else
                      valuesStr = [valuesStr sprintf('   %s\n',num2str(values{idx}))];  %#ok grow
                  end
              catch
                      valuesStr = [valuesStr sprintf('   %s\n',num2str(values{idx}))];  %#ok grow
              end
          end
          values = valuesStr;
      catch
          values = regexprep(evalc('disp(values)'), ' ''([^\n]*)''', '$1');
      end
      values = strrep(values, ',', ', ');
      values = regexprep(values, '([\w]+[\.$][\w.$]+)', ['<a href="matlab:' linkTarget '(''$1'')">$1</a>']);
      if values(end)==10,  values(end)=[];  end
  catch
      % never mind...
      a=1;  %#ok debug breakpoint
  end
  disp(values);
end  % dispValues

function cellStr = stripValue(cellStr,value)  %#ok unused
  if ~isempty(cellStr)
      value = regexprep(value,'.*\.','');
      cellStr = setdiff(cellStr, value);
      cellStr(~cellfun('isempty',regexp(cellStr,['^',value]))) = [];  % strip constructors
  end
end  % stripValue

function diffValues2(title,thisClass,superclass,opName,varargin)
    try
        diffValues(title, char(thisClass.getName),  awtinvoke(thisClass,opName), ...
                          char(superclass.getName), awtinvoke(superclass,opName), varargin{:});
    catch
        % Never mind - maybe no superclass...
        diffValues(title, char(thisClass.getName),  awtinvoke(thisClass,opName), '', {}, varargin{:});
    end
end  % diffValues2

end  % checkClass
